library(tidyverse)
library(vroom)
library(tidymodels)
library(DataExplorer)
library(embed)
library(glmnet)









walmart_train <- vroom("train.csv")
walmart_test <- vroom("test.csv")
walmart_features <- vroom("features.csv")
stores <- vroom("stores.csv")

#########
## EDA ##
#########
plot_missing(walmart_features)
plot_missing(walmart_test)
plot_missing(walmart_train)
### Impute Missing Markdowns
walmart_features <- walmart_features %>%
  mutate(across(starts_with("MarkDown"), ~ replace_na(., 0))) %>%
  mutate(across(starts_with("MarkDown"), ~ pmax(., 0))) %>%
  mutate(
    MarkDown_Total = rowSums(across(starts_with("MarkDown")), na.rm = TRUE),
    MarkDown_Flag = if_else(MarkDown_Total > 0, 1, 0),
    MarkDown_Log   = log1p(MarkDown_Total)
  ) %>%
  select(-MarkDown1, -MarkDown2, -MarkDown3, -MarkDown4, -MarkDown5)

## Impute Missing CPI and Unemployment
feature_recipe <- recipe(~., data=walmart_features) %>%
  step_mutate(DecDate = decimal_date(Date)) %>%
  step_impute_bag(CPI, Unemployment,
                  impute_with = imp_vars(DecDate, Store))
imputed_features <- juice(prep(feature_recipe))

imputed_features <- subset(imputed_features, select = -IsHoliday)

walmart_joined <- left_join(walmart_train,imputed_features, by = c("Store", "Date"))

joined_test <- left_join(walmart_test,imputed_features, by = c("Store", "Date"))



walmart_recipe <- recipe(Weekly_Sales ~ ., data = walmart_joined) %>%
  step_mutate(Weekly_Sales = log1p(Weekly_Sales)) %>%
  step_interact(~ MarkDown_Log:IsHoliday) %>%
  step_mutate(IsHoliday = as.factor(IsHoliday), Store = as.factor(Store), Dept = as.factor(Dept))%>%
  step_lencode_mixed(Store, Dept, outcome = vars(Weekly_Sales)) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_date(Date, features = "doy") %>%
  step_range(Date_doy, min=0, max=2*pi) %>%
  step_mutate(sinDOY=sin(Date_doy), cosDOY=cos(Date_doy)) %>%
  step_normalize(all_numeric_predictors())%>%
  step_zv(all_predictors())%>%
  step_rm(Date)%>%
  step_rm(MarkDown_Total)

  


subset_data <- walmart_joined %>% 
  filter(Store %in% c(1, 2, 4, 7, 10),
         Dept  %in% c(1, 2, 3, 5))

## Boosted Tree Model


# xgb_mod <- (mtry = tune(), min_n = tune(), trees = 500) %>%
#   set_engine("ranger", probability = TRUE, importance = "impurity") %>%
#   set_mode("classification")




## GLM net
glmn_mod <- 
  linear_reg(
    penalty = tune(),   # this is glmnet's lambda
    mixture = tune()    # this is glmnet's alpha
  ) %>% 
  set_engine("glmnet")

glmn_wf <- workflow() %>% add_recipe(walmart_recipe) %>% add_model(glmn_mod)

# grid
glmn_grid <- grid_regular(
  mixture(range = c(0, 1)),
  penalty(range = c(-4, 1)),
  levels = 5
)

# stratified CV
folds <- vfold_cv(subset_data, v = 7)

glmn_res <- glmn_wf %>%
  tune_grid(
    resamples = folds,
    grid      = glmn_grid,
    metrics   = metric_set(rmse),
    control   = control_grid(save_pred = TRUE)
  )

collect_metrics(glmn_res)

show_best(glmn_res, metric = "rmse", n = 1)


best_glmn <- select_best(glmn_res, metric = "rmse")
best_glmn


## KNN

# ## ---- KNN model (tune K) ----
knn_model <- nearest_neighbor(
  mode      = "regression",
  neighbors = tune()                 # <- tune K
) %>%
  set_engine("kknn")

## KNN needs standardized predictors
knn_recipe <- walmart_recipe %>%
  step_normalize(all_predictors())

knn_wf <- workflow() %>%
  add_recipe(knn_recipe) %>%
  add_model(knn_model)


folds <- vfold_cv(subset_data, v = 10)

## Grid over K
knn_grid <- grid_regular(
  neighbors(range = c(2L, 101L)),
  levels = 30
)

## Tune K by RMSE
knn_res <- tune_grid(
  knn_wf,
  resamples = folds,
  grid      = knn_grid,
  metrics   = metric_set(rmse),
  control   = control_grid(save_pred = TRUE)
)
collect_metrics(knn_res)

show_best(knn_res, metric = "rmse", n = 1)



##########################################
## Fit Prophet Model to see how it does ##
##########################################
sort(table(walmart_joined$Store), decreasing = TRUE)

sort(table(walmart_joined$Dept), decreasing = TRUE)


walmart_joined %>% 
  count(Store, Dept, sort = TRUE)


## Choose Store and Dept
store <-  13
dept <- 1
store2 <- 4
dept2 <- 7

library(prophet)

  
## Filter and Rename to match prophet syntax
sd_train <- walmart_joined %>%
filter(Store==store, Dept==dept) %>%
rename(y=Weekly_Sales, ds=Date)
sd_test <- joined_test %>%
filter(Store==store, Dept==dept) %>%
rename(ds=Date)

## Fit a prophet model
prophet_model <- prophet() %>%
  add_regressor("CPI") %>%
  add_regressor("Unemployment") %>%
  add_regressor("MarkDown_Total") %>%
  add_regressor("MarkDown_Flag") %>%
  add_regressor("IsHoliday") %>%
  fit.prophet(df=sd_train)

fitted_vals <- predict(prophet_model, df=sd_train) #For Plotting Fitted Values
test_preds <- predict(prophet_model, df=sd_test) #Predictions are called "yhat"

## Plot Fitted and Forecast on Same Plot
ggplot() +
geom_line(data = sd_train, mapping = aes(x = ds, y = y, color = "Data")) +
geom_line(data = fitted_vals, mapping = aes(x = as.Date(ds), y = yhat, color = "Fitted")) +
geom_line(data = test_preds, mapping = aes(x = as.Date(ds), y = yhat, color = "Forecast")) +
scale_color_manual(values = c("Data" = "black", "Fitted" = "blue", "Forecast" = "red")) +
labs(color="")







