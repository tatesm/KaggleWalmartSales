library(tidyverse)
library(vroom)
library(tidymodels)
library(DataExplorer)










train <- vroom("train.csv")
test <- vroom("test.csv")
features <- vroom("features.csv")
stores <- vroom("stores.csv")

#########
## EDA ##
#########
plot_missing(features)
plot_missing(test)

### Impute Missing Markdowns
features <- features %>%
  mutate(across(starts_with("MarkDown"), ~ replace_na(., 0))) %>%
  mutate(across(starts_with("MarkDown"), ~ pmax(., 0))) %>%
  mutate(
    MarkDown_Total = rowSums(across(starts_with("MarkDown")), na.rm = TRUE),
    MarkDown_Flag = if_else(MarkDown_Total > 0, 1, 0),
    MarkDown_Log   = log1p(MarkDown_Total)
  ) %>%
  select(-MarkDown1, -MarkDown2, -MarkDown3, -MarkDown4, -MarkDown5)

## Impute Missing CPI and Unemployment
feature_recipe <- recipe(~., data=features) %>%
  step_mutate(DecDate = decimal_date(Date)) %>%
  step_impute_bag(CPI, Unemployment,
                  impute_with = imp_vars(DecDate, Store))
imputed_features <- juice(prep(feature_recipe))