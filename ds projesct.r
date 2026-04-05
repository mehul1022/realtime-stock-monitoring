install.packages(c("alphavantager", "tidyverse", "tidyquant", "tidymodels"))
# 1. Load Essential Libraries
library(alphavantager)
library(tidyquant)
library(tidymodels)
library(tidyverse)
library(plotly)
library(lubridate)
library(TTR)
 
# 2. API Key
MY_API_KEY <- "LIPDWB7DHHFS1E7T"
av_api_key(MY_API_KEY)
 
# 3. Helper Functions
 
# --- Fetch and process one stock ---
fetch_and_process <- function(symbol) {
  message("Fetching data for: ", symbol)
 
  # Free tier rate limit: 5 calls/min. Add a pause between calls.
  Sys.sleep(15)
 
  raw <- tryCatch(
    av_get(
      symbol     = symbol,
      av_fun     = "TIME_SERIES_DAILY",
      outputsize = "compact"         # last 100 trading days
    ),
    error = function(e) {
      message("  ERROR fetching ", symbol, ": ", e$message)
      return(NULL)
    }
  )
 
  if (is.null(raw) || nrow(raw) == 0) {
    message("  No data returned for ", symbol)
    return(NULL)
  }
 
  # TIME_SERIES_DAILY returns: timestamp, open, high, low, close, volume
  processed <- raw %>%
    arrange(timestamp) %>%
    rename(
      adjusted_open   = open,
      adjusted_high   = high,
      adjusted_low    = low,
      adjusted_close  = close,
      adjusted_volume = volume
    ) %>%
    mutate(
      # Target: next day's closing price
      target  = lead(adjusted_close),
      # 20-day simple moving average
      sma_20  = zoo::rollmean(adjusted_close, k = 20, fill = NA, align = "right"),
      # 14-day RSI
      rsi     = TTR::RSI(adjusted_close, n = 14),
      # Daily return (%)
      daily_return = (adjusted_close / lag(adjusted_close) - 1) * 100,
      symbol  = symbol
    ) %>%
    drop_na()
 
  return(processed)
}
 
# --- Train model and predict next day ---
train_and_predict <- function(df, symbol) {
  if (is.null(df) || nrow(df) < 30) {
    message("  Not enough data to model ", symbol)
    return(NULL)
  }
 
  split    <- initial_time_split(df, prop = 0.8)
  train_df <- training(split)
  test_df  <- testing(split)
 
  # Linear regression: predict target (next close) from features
  lm_fit <- linear_reg() %>%
    set_engine("lm") %>%
    fit(target ~ adjusted_close + sma_20 + rsi + daily_return, data = train_df)
 
  # Evaluate on test set
  test_preds <- predict(lm_fit, new_data = test_df) %>%
    bind_cols(test_df %>% select(target))
 
  rmse_val <- rmse(test_preds, truth = target, estimate = .pred)$.estimate
  rsq_val  <- rsq(test_preds,  truth = target, estimate = .pred)$.estimate
 
  # Predict next trading day using latest available record
  latest <- tail(df, 1)
  next_pred <- predict(lm_fit, new_data = latest)$.pred
 
  list(
    symbol          = symbol,
    df              = df,
    lm_fit          = lm_fit,
    rmse            = round(rmse_val, 4),
    rsq             = round(rsq_val,  4),
    latest_price    = latest$adjusted_close,
    latest_date     = latest$timestamp,
    predicted_price = next_pred,
    predicted_date  = latest$timestamp + days(1)
  )
}
 
# ============================================================
# 4. Run Pipeline for Each Stock
# ============================================================
 
symbols <- c("AAPL", "MSFT", "SMSN.L")   # Apple, Microsoft, Samsung GDR
 
# Fetch all stocks (with sleep between each to respect rate limits)
stock_data <- map(symbols, fetch_and_process)
names(stock_data) <- symbols
 
# Train models and generate predictions
results <- map2(stock_data, symbols, ~ train_and_predict(.x, .y))
names(results) <- symbols
 
# Remove any failed stocks
results <- Filter(Negate(is.null), results)
 
if (length(results) == 0) stop("No models were successfully built. Check API key and symbols.")
 
# ============================================================
# 5. Print Summary Table
# ============================================================
 
summary_df <- map_dfr(results, function(r) {
  data.frame(
    Stock            = r$symbol,
    Latest_Date      = format(r$latest_date, "%Y-%m-%d"),
    Current_Price    = round(r$latest_price, 2),
    Predicted_Price  = round(r$predicted_price, 2),
    Change_Pct       = round((r$predicted_price / r$latest_price - 1) * 100, 2),
    RMSE             = r$rmse,
    R_Squared        = r$rsq,
    stringsAsFactors = FALSE
  )
})
 
cat("\n========== PREDICTION SUMMARY ==========\n")
print(summary_df, row.names = FALSE)
cat("=========================================\n\n")
 
# ============================================================
# 6. Individual Stock Charts (one per stock)
# ============================================================
 
stock_plots <- map(results, function(r) {
 
  plot_df <- tail(r$df, 30)   # last 30 trading days
 
  current_df <- data.frame(
    timestamp      = r$latest_date,
    adjusted_close = r$latest_price
  )
 
  predicted_df <- data.frame(
    timestamp      = r$predicted_date,
    adjusted_close = r$predicted_price
  )
 
  direction <- ifelse(r$predicted_price >= r$latest_price, "UP ▲", "DOWN ▼")
  pred_color <- ifelse(r$predicted_price >= r$latest_price, "#27ae60", "#e74c3c")
 
  p <- ggplot(plot_df, aes(x = timestamp, y = adjusted_close)) +
    geom_line(color = "#2c3e50", linewidth = 0.8) +
    geom_point(color = "#2c3e50", size = 1.5) +
    # 20-day SMA overlay
    geom_line(aes(y = sma_20), color = "#f39c12",
              linewidth = 0.7, linetype = "dashed", na.rm = TRUE) +
    # Current (latest) price — green diamond
    geom_point(data = current_df,
               aes(x = timestamp, y = adjusted_close),
               color = "#27ae60", size = 5, shape = 18) +
    # Predicted price — red/green triangle
    geom_point(data = predicted_df,
               aes(x = timestamp, y = adjusted_close),
               color = pred_color, size = 5, shape = 17) +
    # Dotted connector line
    geom_segment(
      aes(x = r$latest_date, xend = r$predicted_date,
          y = r$latest_price, yend = r$predicted_price),
      linetype = "dotted", color = "grey50", linewidth = 0.8
    ) +
    labs(
      title    = paste0(r$symbol, " — Last 30 Days + Next-Day Prediction"),
      subtitle = paste0(
        "Current (", format(r$latest_date, "%Y-%m-%d"), "): ",
        round(r$latest_price, 2), "  |  ",
        "Predicted (", format(r$predicted_date, "%Y-%m-%d"), "): ",
        round(r$predicted_price, 2), "  [", direction, "]",
        "\nModel R² = ", r$rsq, "  |  RMSE = ", r$rmse
      ),
      x        = "Date",
      y        = "Close Price",
      caption  = "Dashed = 20-day SMA  |  ◆ Current Price  |  ▲ Predicted Price"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10, color = "grey40"),
      plot.caption  = element_text(size = 9,  color = "grey50")
    )
 
  ggplotly(p, tooltip = c("x", "y")) %>%
    layout(
      hoverlabel = list(bgcolor = "white"),
      legend     = list(orientation = "h")
    )
})
 
# ============================================================
# 7. Combined Multi-Stock Overview Chart
# ============================================================
 
# Normalise prices to 100 at the start of the window for fair comparison
combined_df <- map_dfr(results, function(r) {
  df30 <- tail(r$df, 30)
  base <- df30$adjusted_close[1]
  df30 %>%
    mutate(
      normalised = (adjusted_close / base) * 100,
      symbol     = r$symbol
    ) %>%
    select(timestamp, adjusted_close, normalised, symbol)
})
 
p_combined <- ggplot(combined_df,
                     aes(x = timestamp, y = normalised,
                         color = symbol, group = symbol)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  scale_color_manual(values = c("AAPL" = "#1f77b4",
                                "MSFT" = "#ff7f0e",
                                "SMSN.L" = "#2ca02c")) +
  labs(
    title    = "Normalised Price Comparison (Last 30 Days, Base = 100)",
    subtitle = "Allows direct comparison of relative performance across stocks",
    x        = "Date",
    y        = "Normalised Price (Base 100)",
    color    = "Stock"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))
 
p_combined_plotly <- ggplotly(p_combined, tooltip = c("x", "y", "colour"))
 
# ============================================================
# 8. Display All Charts
# ============================================================
 
# Individual stock charts
for (sym in names(stock_plots)) {
  cat("Displaying chart for:", sym, "\n")
  print(stock_plots[[sym]])
}
 
# Combined comparison chart
cat("Displaying combined comparison chart\n")
print(p_combined_plotly)
 
cat("\nDone! All charts displayed.\n")
 