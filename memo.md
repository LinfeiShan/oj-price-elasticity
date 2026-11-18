# Memo: Pricing Orange Juice at Dominick's

**To:** Category Manager, Refrigerated Juice
**From:** Linfei (Sophie) Shan
**Re:** What 2.3 years of scanner data say about price sensitivity, competition and markups

---

## Bottom line

Orange juice shoppers are highly price-sensitive. A 10% price cut raises unit sales by about 32% on average, or about 36% once price endogeneity is corrected. Sensitivity varies a lot by brand, by whether the product is advertised, and by neighbourhood. That makes a single chain-wide price strategy leave money on the table.

## What I did

I estimated log-log demand curves on 106,139 store-brand-week observations: 83 stores, 11 brands, weeks 40–160. The model controls for each brand's baseline popularity, each store's size and each week's chain-wide conditions using fixed effects. Standard errors are clustered by store.

To check that the results aren't driven by stores reacting to local demand, I re-estimated the model using each brand's price in the chain's other stores as an instrument.

## Findings

**1. Elasticities are large, and brand matters.**

| Brand | Elasticity | Implied optimal markup (−1/ε) |
|---|---|---|
| Tropicana 64oz | −3.90 | 26% |
| Minute Maid 64oz | −3.48 | 29% |
| Dominick's 64oz | −3.37 | 30% |
| Tropicana Premium 64oz | −2.87 | 35% |
| Dominick's 128oz | −1.89 | 53% |

The mainstream 64oz brands are the most price-sensitive, which makes them good traffic-driving promotions. Premium and large-size products are less sensitive and can carry higher margins.

**2. Advertising makes shoppers more price-responsive.** Elasticity rises from −2.97 to −3.87 when a brand is fully featured in the weekly ad. So the feature ad and the price cut reinforce each other, and they should be scheduled together. In-store deals alone had no measurable effect.

**3. National brands win the price war against the store brand.** A 1% Tropicana price cut lowers Dominick's 64oz sales by about 0.9%. A 1% Dominick's price cut lowers Tropicana sales by only about 0.35%. Discounting national brands therefore cannibalises the higher-margin store brand.

**4. Neighbourhood income matters.** Stores in areas with income one standard deviation above average have elasticities about 0.44 closer to zero. Across the 83 stores, elasticity ranges from about −4.5 to −2.3.

## Recommendations

1. **Use store-zone pricing:** set shallower discounts and higher regular prices in higher-income stores.
2. **Time national-brand promotions carefully.** Each one pulls volume from the store brand, so judge them on category profit, not brand volume.
3. **Protect margins on 128oz and premium products.** Their low price sensitivity supports it.

## Caveats

Weekly data capture short-run promotional responses, including stocking up, so long-run elasticities are smaller. Lerner markups ignore cross-brand effects: a retailer optimising the whole category should set somewhat lower markups than the single-brand benchmark.

*Code, data and full results: see README.md and code/01_elasticity_analysis.R.*
