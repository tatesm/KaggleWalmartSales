# Walmart Weekly Sales Forecasting (Kaggle)

This project focuses on forecasting weekly department-level sales using historical Walmart retail data. The work emphasizes data preparation, feature engineering, and comparison of multiple modeling approaches under a weighted error metric that prioritizes holiday accuracy.

The project was completed as part of applied modeling coursework and is intended to demonstrate practical forecasting workflows rather than leaderboard optimization.

## Problem Description
Retail forecasting presents unique challenges due to limited historical coverage of key events. Holidays and markdown promotions occur infrequently but have outsized impacts on revenue, making generalization difficult.

In this Kaggle recruiting competition, participants are provided with historical sales data for 45 Walmart stores across multiple departments and are tasked with predicting weekly sales. Errors during holiday weeks are penalized more heavily, reflecting real business priorities.

## Data Sources
The following Kaggle datasets are used:
- `train.csv` – historical weekly sales
- `test.csv` – weeks requiring forecasts
- `features.csv` – economic indicators, markdowns, and holidays
- `stores.csv` – store-level metadata

## Exploratory Data Analysis
- Evaluated missingness across all datasets using `DataExplorer`
- Identified extensive missing values in markdown variables, CPI, and unemployment
- Inspected holiday effects and promotional sparsity across departments and stores

## Feature Engineering
Key preprocessing and feature design steps include:
- Imputation of missing markdown values using zeros with non-negativity constraints
- Aggregation of markdown variables into:
  - Total markdown amount
  - Binary markdown indicator
  - Log-transformed markdown total
- Bagged-tree imputation of CPI and unemployment using temporal and store-level context
- Log transformation of the response variable (`Weekly_Sales`)
- Seasonal encoding using sine and cosine of day-of-year
- Encoding of store and department effects using target encoding and dummy variables
- Removal of zero-variance and redundant predictors

## Modeling Approaches

### Regularized Regression (Elastic Net)
- Elastic net regression implemented via `glmnet`
- Tuned penalty (lambda) and mixture (alpha) parameters
- Cross-validation using v-fold resampling
- Model selection based on RMSE

### k-Nearest Neighbors (KNN)
- Regression-based KNN model
- Predictor standardization via preprocessing recipe
- Tuned number of neighbors using cross-validation
- Evaluated using RMSE

### Time Series Forecasting (Prophet)
- Applied to selected store-department combinations
- Incorporated external regressors:
  - CPI
  - Unemployment
  - Markdown features
  - Holiday indicators
- Visualized fitted values and out-of-sample forecasts

## Evaluation Metric
Model performance was evaluated using **Weighted Mean Absolute Error (WMAE)**, defined as:

- Weight = 5 for holiday weeks
- Weight = 1 for non-holiday weeks

This metric reflects the higher business cost of poor holiday forecasts.

## Kaggle Submission Results
A valid submission was generated and evaluated on Kaggle’s public and private leaderboards.

- Public leaderboard WMAE: ~3467  
- Private leaderboard WMAE: ~3297  

The priv


