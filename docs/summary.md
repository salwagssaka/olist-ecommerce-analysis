# Olist E-commerce Analysis: Key Findings

Scope: 96K delivered orders (2017-2018), ~93K unique customers, 13.2M BRL revenue.
Tools: MySQL (extraction), Python/pandas (cleaning), Power BI (dashboard).

## 1. Late deliveries are strongly associated with low review scores
- 8.1% of orders arrive after the estimated date.
- Late orders score 2.57 on average vs 4.29 for on-time ones (-40%).
- Scores fall from 4.3 (early) to 3.3 (1-3 days late), 2.1 (4-7 days late),
  and 1.7 beyond one week. After about a week, satisfaction hits its floor.
- Late-delivery rates are highest in the northeast (AL 23.9%, MA 19.7%).
  Rio de Janeiro (RJ) also has a high rate (13.5%).

Recommendation: prioritize avoiding even short delays. Flag orders at risk of passing
the one-week mark for proactive communication or compensation, and investigate logistics performance first in the northeast and RJ.

## 2. Almost no customers come back
- 97.0% of customers placed a single order; only 3.0% ordered twice or more.
- Only about 2% of customers fall in the active repeat-buyer ("Loyal") RFM segment.

Recommendation: launch a retention program aimed at first-time buyers (post-purchase
email, second-order incentive), and measure the repeat-purchase rate as a KPI.

## 3. Revenue growth stalled in 2018
- Monthly revenue grew about 9x during 2017 (0.11M in January to 0.99M in
  November, the Black Friday peak), then plateaued between 0.85M and 0.98M in 2018.
- The top categories are health_beauty, watches_gifts and bed_bath_table.

Recommendation: with so few repeat buyers, growth depends on acquiring new customers.
Improving retention and delivery reliability is a more reliable path to growth.

## Limitations
- Review scores are associated with late delivery, not proven to be caused by it.
- Small states have few orders, so their late-delivery rates are less reliable.
- The dataset covers 2016-2018 only; the first and last months are incomplete and
  were excluded from the trend chart.