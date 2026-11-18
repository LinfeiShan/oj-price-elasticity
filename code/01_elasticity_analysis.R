# =============================================================================
# How Price-Sensitive Are Orange Juice Shoppers?
# Estimating own- and cross-price elasticities with Dominick's scanner data
#
# Author: Linfei (Sophie) Shan
# Data:   Dominick's Finer Foods refrigerated orange juice, 83 Chicago-area
#         stores, 11 brands, weeks 40-160 (Montgomery 1997, Marketing Science;
#         distributed in the R package `bayesm` as `orangeJuice`).
#
# Run from the project root:   Rscript code/01_elasticity_analysis.R
# Packages: sandwich, lmtest, AER, ggplot2   (install.packages(c(...)))
# =============================================================================

suppressPackageStartupMessages({
  library(sandwich)  # cluster-robust standard errors
  library(lmtest)    # coeftest() to print coefficients with those SEs
  library(AER)       # ivreg() for the instrumental-variables check
  library(ggplot2)   # charts
})

dir.create("output/tables",  recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
log_file <- "output/regression_results.txt"
sink(log_file, split = TRUE)   # everything printed below also goes to the log

# -----------------------------------------------------------------------------
# 1. Load and prepare the data
# -----------------------------------------------------------------------------
# orangeJuice.rda is the dataset exactly as shipped in the bayesm package:
# a list with yx (store x brand x week sales) and storedemo (store demographics)
load("data/orangeJuice.rda")
yx   <- orangeJuice$yx
demo <- orangeJuice$storedemo

brand_names <- c("Tropicana Premium 64oz", "Tropicana Premium 96oz",
                 "Florida's Natural 64oz", "Tropicana 64oz",
                 "Minute Maid 64oz", "Minute Maid 96oz", "Citrus Hill 64oz",
                 "Tree Fresh 64oz", "Florida Gold 64oz",
                 "Dominick's 64oz", "Dominick's 128oz")

# Each row lists the price of ALL 11 brands in that store-week; the brand's own
# price is the column matching its brand number. Prices are dollars per ounce.
price_cols   <- paste0("price", 1:11)
price_matrix <- as.matrix(yx[, price_cols])
yx$own_price <- price_matrix[cbind(seq_len(nrow(yx)), yx$brand)]

yx$log_price  <- log(yx$own_price)
yx$brand_name <- factor(brand_names[yx$brand], levels = brand_names)
yx$store_f    <- factor(yx$store)   # store fixed effects
yx$week_f     <- factor(yx$week)    # week fixed effects (seasonality, shocks)

# Store demographics: standardise income so the interaction reads "per 1 SD"
demo$income_z <- as.numeric(scale(demo$INCOME))
yx <- merge(yx, demo[, c("STORE", "INCOME", "income_z", "EDUC", "AGE60")],
            by.x = "store", by.y = "STORE", all.x = TRUE)

cat("Observations:", nrow(yx), "| stores:", length(unique(yx$store)),
    "| brands:", length(unique(yx$brand)),
    "| weeks:", min(yx$week), "-", max(yx$week), "\n\n")

# Helper: coefficients with standard errors clustered by store
# (sales in the same store are correlated over time, so plain OLS SEs are too small)
robust <- function(model) coeftest(model, vcov = vcovCL(model, cluster = ~store))

# -----------------------------------------------------------------------------
# 2. Descriptive table: average price and sales by brand
# -----------------------------------------------------------------------------
desc <- aggregate(cbind(price_64oz = own_price * 64, units = exp(logmove),
                        featured = feat) ~ brand_name, data = yx, FUN = mean)
desc$price_64oz <- round(desc$price_64oz, 2)
desc$units      <- round(desc$units)
desc$featured   <- round(desc$featured, 3)
names(desc) <- c("brand", "avg_price_per_64oz_usd", "avg_weekly_units_per_store",
                 "avg_feature_share")
write.csv(desc, "output/tables/descriptives_by_brand.csv", row.names = FALSE)
cat("== Descriptives by brand ==\n"); print(desc, row.names = FALSE); cat("\n")

# -----------------------------------------------------------------------------
# 3. Pooled elasticity: from naive to controlled
#    log(Q) = a + e * log(P) + controls  ->  e is the price elasticity
# -----------------------------------------------------------------------------
m_naive <- lm(logmove ~ log_price, data = yx)
m_brand <- lm(logmove ~ log_price + brand_name, data = yx)
m_full  <- lm(logmove ~ log_price + feat + deal + brand_name + store_f + week_f,
              data = yx)

pooled <- data.frame(
  model = c("(1) No controls", "(2) + brand fixed effects",
            "(3) + store & week FE, feature, deal"),
  elasticity = c(coef(m_naive)["log_price"], coef(m_brand)["log_price"],
                 coef(m_full)["log_price"]),
  se_clustered = c(sqrt(vcovCL(m_naive, cluster = ~store)["log_price", "log_price"]),
                   sqrt(vcovCL(m_brand, cluster = ~store)["log_price", "log_price"]),
                   sqrt(vcovCL(m_full,  cluster = ~store)["log_price", "log_price"])))
pooled[, 2:3] <- round(pooled[, 2:3], 3)
write.csv(pooled, "output/tables/pooled_elasticity.csv", row.names = FALSE)
cat("== Pooled own-price elasticity ==\n"); print(pooled, row.names = FALSE)
cat("\nModel (3) feature & deal coefficients (clustered SEs):\n")
print(robust(m_full)[c("log_price", "feat", "deal"), ]); cat("\n")

# -----------------------------------------------------------------------------
# 4. Brand-specific own-price elasticities
# -----------------------------------------------------------------------------
m_brandel <- lm(logmove ~ brand_name + brand_name:log_price + feat + deal +
                  store_f + week_f, data = yx)
ct  <- robust(m_brandel)
idx <- grep(":log_price$", rownames(ct))
brand_el <- data.frame(
  brand      = sub("^brand_name(.*):log_price$", "\\1", rownames(ct)[idx]),
  elasticity = ct[idx, 1], se = ct[idx, 2])
brand_el$ci_low  <- brand_el$elasticity - 1.96 * brand_el$se
brand_el$ci_high <- brand_el$elasticity + 1.96 * brand_el$se
# Inverse-elasticity (Lerner) rule: profit-maximising markup (P - MC) / P = -1/e
brand_el$lerner_markup <- ifelse(brand_el$elasticity < -1, -1 / brand_el$elasticity, NA)
brand_el <- merge(brand_el, desc[, c("brand", "avg_price_per_64oz_usd")], by = "brand")
brand_el <- brand_el[order(brand_el$elasticity), ]
out <- brand_el; out[, sapply(out, is.numeric)] <- round(out[, sapply(out, is.numeric)], 3)
write.csv(out, "output/tables/brand_elasticities.csv", row.names = FALSE)
cat("== Brand-specific own-price elasticities (store & week FE, clustered SEs) ==\n")
print(out, row.names = FALSE); cat("\n")

# -----------------------------------------------------------------------------
# 5. Does feature advertising change price sensitivity?
# -----------------------------------------------------------------------------
# Centre log price so the "feat" coefficient is the feature effect at the
# average price (otherwise it is the effect at log price = 0, which is meaningless)
yx$log_price_c <- yx$log_price - mean(yx$log_price)
m_feat <- lm(logmove ~ log_price_c * feat + deal + brand_name + store_f + week_f,
             data = yx)
rf <- robust(m_feat)
cat("== Price x feature advertising (log price centred) ==\n")
print(rf[c("log_price_c", "feat", "log_price_c:feat"), ])
cat("Elasticity when not featured:", round(rf["log_price_c", 1], 2),
    "| when fully featured:", round(rf["log_price_c", 1] + rf["log_price_c:feat", 1], 2), "\n\n")

# -----------------------------------------------------------------------------
# 6. Are shoppers in richer neighbourhoods less price-sensitive?
# -----------------------------------------------------------------------------
m_inc <- lm(logmove ~ log_price * income_z + feat + deal + brand_name +
              store_f + week_f, data = yx)
cat("== Price x store income (income standardised: 1 = one SD above mean) ==\n")
print(robust(m_inc)[c("log_price", "log_price:income_z"), ]); cat("\n")

# Store-level elasticities (one regression per store) for the income chart
store_el <- do.call(rbind, lapply(split(yx, yx$store), function(d) {
  m <- lm(logmove ~ log_price + feat + deal + brand_name + week_f, data = d)
  data.frame(store = d$store[1], elasticity = coef(m)["log_price"],
             income = d$INCOME[1])
}))
write.csv(store_el, "output/tables/store_elasticities.csv", row.names = FALSE)

# -----------------------------------------------------------------------------
# 7. Cross-price elasticities among the three big 64oz brands
#    Positive cross-elasticity = substitutes: competitor's price up -> my sales up
# -----------------------------------------------------------------------------
focus <- c(4, 5, 10)   # Tropicana 64oz, Minute Maid 64oz, Dominick's 64oz
yx$lp4 <- log(yx$price4); yx$lp5 <- log(yx$price5); yx$lp10 <- log(yx$price10)
# Stack the three brands in one regression with the SAME store and week fixed
# effects as the main model, so own-price effects stay comparable to Section 4.
# Each brand gets its own coefficient on each of the three prices.
d3 <- yx[yx$brand %in% focus, ]
d3$brand_name <- droplevels(d3$brand_name)
m_cross <- lm(logmove ~ brand_name + brand_name:(lp4 + lp5 + lp10) + feat + deal +
                store_f + week_f, data = d3)
rc <- robust(m_cross)
cross <- matrix(NA, 3, 3, dimnames = list(
  paste("Sales of", brand_names[focus]), paste("Price of", brand_names[focus])))
cross_se <- cross
for (i in seq_along(focus)) for (j in seq_along(focus)) {
  term <- paste0("brand_name", brand_names[focus[i]], ":lp", focus[j])
  cross[i, j] <- rc[term, 1]; cross_se[i, j] <- rc[term, 2]
}
write.csv(round(cross, 3), "output/tables/cross_price_elasticities.csv")
write.csv(round(cross_se, 3), "output/tables/cross_price_elasticities_se.csv")
cat("== Cross-price elasticity matrix (rows: whose sales; cols: whose price) ==\n")
print(round(cross, 2)); cat("Clustered SEs:\n"); print(round(cross_se, 2)); cat("\n")

# -----------------------------------------------------------------------------
# 8. Robustness: instrumental variables (Hausman instrument)
#    Worry: stores may cut prices when demand is weak (or raise them when it is
#    strong), biasing OLS. Instrument a brand's price in store s, week t with its
#    average price in all OTHER stores that week: it moves with chain-wide cost
#    and promotion decisions, not with store s's local demand shock.
# -----------------------------------------------------------------------------
grp_sum <- ave(yx$log_price, yx$brand, yx$week, FUN = sum)
grp_n   <- ave(yx$log_price, yx$brand, yx$week, FUN = length)
yx$iv_price <- (grp_sum - yx$log_price) / (grp_n - 1)   # leave-one-out mean
m_iv <- ivreg(logmove ~ log_price + feat + deal + brand_name + store_f + week_f |
                iv_price + feat + deal + brand_name + store_f + week_f, data = yx)
first <- lm(log_price ~ iv_price + feat + deal + brand_name + store_f + week_f,
            data = yx)
fs_t <- robust(first)["iv_price", "t value"]
cat("== IV estimate (Hausman instrument) ==\n")
print(robust(m_iv)["log_price", ])
cat("First-stage t-statistic on instrument:", round(fs_t, 1),
    "(F =", round(fs_t^2), "; >10 means a strong instrument)\n\n")

summary_tbl <- data.frame(
  estimate = c("OLS, store & week FE", "IV (Hausman instrument)"),
  elasticity = round(c(coef(m_full)["log_price"], coef(m_iv)["log_price"]), 3),
  se = round(c(robust(m_full)["log_price", 2], robust(m_iv)["log_price", 2]), 3))
write.csv(summary_tbl, "output/tables/ols_vs_iv.csv", row.names = FALSE)

# -----------------------------------------------------------------------------
# 9. Figures
# -----------------------------------------------------------------------------
theme_set(theme_minimal(base_size = 12))

# 9a. Brand elasticities with 95% confidence intervals
brand_el$brand <- factor(brand_el$brand, levels = brand_el$brand)
p1 <- ggplot(brand_el, aes(x = elasticity, y = brand)) +
  geom_vline(xintercept = -1, linetype = "dashed", colour = "grey50") +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.25, colour = "#2C6E91") +
  geom_point(size = 2.6, colour = "#2C6E91") +
  annotate("text", x = -1.05, y = 11.4, label = "unit elastic (-1)", hjust = 1,
           size = 3.2, colour = "grey40") +
  labs(title = "Own-price elasticity by brand",
       subtitle = "Log-log demand with store and week fixed effects; 95% CI, SEs clustered by store",
       x = "Elasticity (% change in units for a 1% price increase)", y = NULL)
ggsave("output/figures/fig1_brand_elasticities.png", p1, width = 8, height = 5, dpi = 200)

# 9b. Raw relationship: price vs. sales for the three big 64oz brands
sub <- yx[yx$brand %in% focus, ]
p2 <- ggplot(sub, aes(x = own_price * 64, y = logmove)) +
  geom_point(alpha = 0.06, size = 0.6, colour = "#2C6E91") +
  geom_smooth(method = "lm", formula = y ~ log(x), colour = "#C0392B", se = FALSE) +
  facet_wrap(~ brand_name) +
  labs(title = "Lower prices, more units: the raw data",
       subtitle = "Each dot is one store-week",
       x = "Price per 64oz carton (USD)", y = "log(units sold)")
ggsave("output/figures/fig2_price_vs_sales.png", p2, width = 9, height = 3.8, dpi = 200)

# 9c. Store elasticity vs. neighbourhood income
p3 <- ggplot(store_el, aes(x = exp(income), y = elasticity)) +
  geom_point(colour = "#2C6E91", size = 2) +
  geom_smooth(method = "lm", formula = y ~ x, colour = "#C0392B", se = TRUE) +
  labs(title = "Shoppers in richer neighbourhoods are less price-sensitive",
       subtitle = "One point per store (83 stores)",
       x = "Median household income of store's area (USD)",
       y = "Store-level price elasticity")
ggsave("output/figures/fig3_elasticity_vs_income.png", p3, width = 7, height = 4.5, dpi = 200)

# 9d. Cross-price heatmap
cdf <- as.data.frame(as.table(cross))
names(cdf) <- c("sales_of", "price_of", "elasticity")
p4 <- ggplot(cdf, aes(x = price_of, y = sales_of, fill = elasticity)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", elasticity)), size = 4.2) +
  scale_fill_gradient2(low = "#C0392B", mid = "white", high = "#2C6E91", midpoint = 0) +
  labs(title = "Who competes with whom?",
       subtitle = "Diagonal = own-price elasticity; off-diagonal > 0 = substitutes",
       x = NULL, y = NULL) +
  theme(axis.text.x = element_text(angle = 15, hjust = 1), legend.position = "none")
ggsave("output/figures/fig4_cross_price_heatmap.png", p4, width = 8, height = 4.5, dpi = 200)

cat("Done. Tables in output/tables, figures in output/figures.\n")
sink()
