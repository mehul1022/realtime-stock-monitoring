Multi-Stock Price Predictor & Visualizer
An automated end-to-end financial analytics pipeline built in R. The tool fetches historical daily stock market data via the Alpha Vantage API, constructs technical indicators (SMA, RSI, returns), trains a predictive linear regression model using tidymodels, and outputs interactive plotly charts displaying next-day price projections.
Features
Automated Ingestion: Fetches daily closing prices using the alphavantager package with built-in rate-limit delays (15-second pauses between requests).
Feature Engineering:
Target: Next-day closing price via lead shifting (dplyr::lead).
20-Day SMA: 20-period simple moving average calculated via zoo::rollmean.
14-Day RSI: Relative Strength Index computed with TTR::RSI.
Daily Return: Daily percentage change.
Time-Series Machine Learning: Uses tidymodels to perform chronological 80/20 train/test splits (initial_time_split) and fits an Ordinary Least Squares (OLS) regression model to project the next trading session's price.
Model Evaluation: Automatically reports Root Mean Squared Error (RMSE) and R-Squared (
R
2
R 
2
 ) values on out-of-sample test splits.
Interactive Visualizations:
Individual stock charts plotting the last 30 trading days, 20-day SMA, current price, and predicted target with color-coded directional signals (Green for Up, Red for Down).
A multi-stock normalized comparison chart (base = 100) to evaluate relative performance across tickers.
Directory Layout
Plaintext
├── stock_predictor.R    # Main analysis and modeling script
└── README.md            # Project documentation
Prerequisites & Installation
Make sure you have R (>= 4.0.0) installed. Install the necessary CRAN dependencies by running:
R
install.packages(c(
  "alphavantager",
  "tidyverse",
  "tidyquant",
  "tidymodels",
  "plotly",
  "lubridate",
  "TTR",
  "zoo"
))
Configuration & Usage
1. API Key Setup
The script requires an Alpha Vantage API key. For security best practices, avoid hardcoding API keys directly in source code. Instead, set it as an environment variable or edit the script locally:
R
# Option A: In the script
MY_API_KEY <- Sys.getenv("ALPHAVANTAGE_API_KEY", "YOUR_API_KEY_HERE")
av_api_key(MY_API_KEY)
(You can obtain a free API key at Alpha Vantage).
2. Configure Tickers
Modify the target symbols in the script:
R
symbols <- c("AAPL", "MSFT", "SMSN.L")
3. Run the Pipeline
Run the script from an interactive R session (RStudio / VS Code) or the command line:
Bash
Rscript stock_predictor.R
Output Examples
Console Summary
Plaintext
========== PREDICTION SUMMARY ==========
 Stock Latest_Date Current_Price Predicted_Price Change_Pct   RMSE R_Squared
  AAPL  2026-03-27        178.50          179.80       0.73 2.1402    0.9120
  MSFT  2026-03-27        420.10          422.30       0.52 3.8911    0.9341
SMSN.L  2026-03-27       1340.00         1335.50      -0.34 8.7610    0.8954
=========================================
Visualization
Individual Charts: Hoverable candlestick-style daily line charts with directional markers showing expected closing price direction.
Comparative Chart: Indexed baseline index (Base = 100) allowing direct growth comparisons across stocks of differing nominal share prices.
Disclaimer
This project is built for educational, quantitative modeling, and demonstration purposes only. It should not be treated as financial advice or an automated trading recommendation engine.
