# 📈 Stock Price Prediction in R

An R pipeline that pulls daily stock data from the [Alpha Vantage](https://www.alphavantage.co/) API, engineers technical indicators, trains a linear regression model with `tidymodels`, and predicts the **next trading day's closing price** for multiple stocks. Results are shown as a summary table and interactive Plotly charts.

> ⚠️ **Disclaimer:** This project is for educational purposes only. It is **not** financial advice. Do not use these predictions to make real investment decisions.

---

## ✨ Features

- Fetches the last ~100 trading days of OHLCV data per stock (Alpha Vantage `TIME_SERIES_DAILY`)
- Built-in pause between API calls to respect the free-tier rate limit (5 calls/min)
- Feature engineering:
  - 20-day Simple Moving Average (SMA)
  - 14-day Relative Strength Index (RSI)
  - Daily percentage return
- Time-ordered 80/20 train/test split (no data leakage from shuffling)
- Linear regression model evaluated with **RMSE** and **R²**
- Next-day price prediction with a summary table (current price, predicted price, % change)
- Interactive charts:
  - One chart per stock (last 30 days + SMA + predicted next-day price)
  - A combined normalised comparison chart (base = 100)

---

## 🧰 Tech Stack

| Package | Purpose |
|---|---|
| `alphavantager` | Fetch stock data from Alpha Vantage |
| `tidyverse` | Data wrangling and plotting (`dplyr`, `ggplot2`, `purrr`, ...) |
| `tidymodels` | Train/test split, modelling, metrics |
| `tidyquant` | Financial data utilities |
| `TTR` | Technical indicators (RSI) |
| `zoo` | Rolling mean (SMA) |
| `plotly` | Interactive charts |
| `lubridate` | Date handling |

---

## 🚀 Getting Started

### 1. Prerequisites

- [R](https://cran.r-project.org/) (version 4.1 or higher recommended)
- [RStudio](https://posit.co/download/rstudio-desktop/) (optional but recommended)
- A free Alpha Vantage API key: https://www.alphavantage.co/support/#api-key

### 2. Install packages

```r
install.packages(c(
  "alphavantager", "tidyverse", "tidyquant",
  "tidymodels", "plotly", "lubridate", "TTR", "zoo"
))
```

### 3. Set your API key (do NOT hardcode it)

Never commit your API key to GitHub. Store it as an environment variable instead.

Add this line to your `~/.Renviron` file (open it with `usethis::edit_r_environ()`):

```
ALPHAVANTAGE_API_KEY=your_api_key_here
```

Restart R, then in the script replace the hardcoded key with:

```r
MY_API_KEY <- Sys.getenv("ALPHAVANTAGE_API_KEY")
av_api_key(MY_API_KEY)
```

### 4. Run the script

```r
source("stock_prediction.R")
```

> Note: Each stock takes about 15 seconds to fetch because of the rate-limit pause, so a 3-stock run takes roughly a minute.

---

## ⚙️ Configuration

Change the stocks you want to analyse by editing this line:

```r
symbols <- c("AAPL", "MSFT", "SMSN.L")
```

Use any ticker supported by Alpha Vantage (for example `GOOGL`, `TSLA`, `AMZN`). Non-US tickers may need an exchange suffix (e.g. `.L` for London).

---

## 🔄 How It Works

1. **Fetch** – Download daily prices for each symbol.
2. **Process** – Sort by date, compute the SMA, RSI and daily return, and create the target column (next day's close).
3. **Split** – First 80% of the timeline for training, last 20% for testing.
4. **Train** – Fit `target ~ adjusted_close + sma_20 + rsi + daily_return` with linear regression.
5. **Evaluate** – Compute RMSE and R² on the test set.
6. **Predict** – Use the latest available row to predict the next trading day's close.
7. **Visualise** – Print the summary table and display interactive charts.

---

## 📊 Example Output

Console summary:

```
========== PREDICTION SUMMARY ==========
 Stock Latest_Date Current_Price Predicted_Price Change_Pct  RMSE R_Squared
  AAPL  2026-10-12        xxx.xx          xxx.xx       0.xx  x.xx      0.xx
  MSFT  2026-10-12        xxx.xx          xxx.xx       0.xx  x.xx      0.xx
...
=========================================
```

Charts (interactive Plotly):

- `AAPL — Last 30 Days + Next-Day Prediction`
- `MSFT — Last 30 Days + Next-Day Prediction`
- `Normalised Price Comparison (Last 30 Days, Base = 100)`

*(Tip: add screenshots to a `/images` folder and link them here.)*

---

## ⚠️ Limitations

- **Small dataset:** The free tier's `compact` output returns only ~100 days, leaving very little data to train and test on.
- **Simple model:** Linear regression on price-derived features mostly learns "tomorrow ≈ today," so it cannot capture news, earnings, or market shocks.
- **Single-step prediction:** Only the next trading day is forecast, and `predicted_date` simply adds one calendar day (it does not skip weekends/holidays).
- **API limits:** The free Alpha Vantage tier allows only 5 calls/minute and a limited number of calls per day.
- **Column naming:** Columns are named `adjusted_*`, but `TIME_SERIES_DAILY` returns unadjusted prices (adjusted data requires a premium endpoint).

---

## 🛣️ Possible Improvements

- Try other models (Random Forest, XGBoost, ARIMA, LSTM)
- Add more indicators (MACD, Bollinger Bands, volume features)
- Use time-series cross-validation (`rolling_origin`)
- Use `outputsize = "full"` for more history
- Skip weekends when computing the predicted date
- Wrap the pipeline in a Shiny dashboard

---

## 📁 Project Structure

```
.
├── stock_prediction.R   # Main script
├── README.md            # Project documentation
└── .gitignore           # Should include .Renviron and .Rhistory
```

---

## 📄 License

This project is licensed under the MIT License. Feel free to use and modify it.

---

## 🙏 Acknowledgements

- [Alpha Vantage](https://www.alphavantage.co/) for the free market data API
- The [tidyverse](https://www.tidyverse.org/) and [tidymodels](https://www.tidymodels.org/) teams
