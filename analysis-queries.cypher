//Find most common emojis used on payment notes
MATCH (e:Emoji)-[r:CONTAINS_EMOJI]-(p:Payment)
RETURN e.emoji, count(p) as payments
ORDER BY payments DESC LIMIT 10;
//Notes: cash with wings, house are most common. Means bills and rent are common payments?

//Find most common emoji categories used
MATCH (c:Category)<-[r:IN]-(e:Emoji)<-[r2:CONTAINS_EMOJI]-(p:Payment)
RETURN c.name, collect(DISTINCT e.emoji) as emojis, count(p) as payments
ORDER BY payments DESC LIMIT 10;
//Notes: food, emotion, drink, body, activities are top 5.
//Take into consideration the number of emojis used in each category (26 in food vs 13 in drink).
//Could mean that paying for food/drink/activities are most common payments?

//Find out distribution of emoji numbers on payments
MATCH (p:Payment)
WITH size([path = (p)-[:CONTAINS_EMOJI]->(:Emoji) | path]) as emojisPerPayment
RETURN DISTINCT emojisPerPayment, count(emojisPerPayment) as numberOfPayments
ORDER BY numberOfPayments DESC;
//Notes: tells us how many emojis exist on a number of payments
//In the results, most payment (5255) have no emojis. Following sets of payments only increases emoji count by 1.

//Find most popular pairs of emojis used together
MATCH (c:Category)<-[:IN]-(e:Emoji)<-[:CONTAINS_EMOJI]-(p:Payment)-[:CONTAINS_EMOJI]->(e2:Emoji)-[:IN]->(c2:Category)
WHERE id(e) < id(e2)
AND id(c) < id(c2)
RETURN e.emoji, e2.emoji, count(p) as cooccurrences
ORDER BY cooccurrences DESC;
//Notes: Lots of overly similar duplicates here

//See what differing emojis are used together
MATCH (c:Category)<-[:IN]-(e:Emoji)<-[:CONTAINS_EMOJI]-(p:Payment)-[:CONTAINS_EMOJI]->(e2:Emoji)-[:IN]->(c2:Category)
WHERE id(e) < id(e2)
AND id(c) < id(c2)
AND NOT EXISTS((e)-[:IN]-(:Category)-[:IN]-(e2))
AND NOT EXISTS((e)-[:SIMILAR]-(e2))
AND NOT EXISTS((c)-[:SIMILAR]-(c2))
RETURN e.emoji, e2.emoji, count(p) as cooccurrences
ORDER BY cooccurrences DESC;
//Notes: Many have gender signs combined with an activity

//Find payments with highest sentiment scores (positive)
MATCH (e:Emoji)<-[r:CONTAINS_EMOJI]-(p:Payment)
WHERE size((p)-[:CONTAINS_EMOJI]-(:Emoji)) > 1
WITH p, e, CASE
 WHEN e.negativeRatio < e.positiveRatio > e.neutralRatio THEN 1
 WHEN e.negativeRatio < e.neutralRatio > e.positiveRatio THEN 0
 WHEN e.neutralRatio < e.negativeRatio > e.positiveRatio THEN -1
 END as sentiments
WITH p, sum(sentiments) as sentimentScore
RETURN p.note, sentimentScore
ORDER BY sentimentScore DESC LIMIT 20;
//Notes: Looks like top ones deal with food or vacation :)

//Find payments with lowest sentiment scores (negative)
MATCH (e:Emoji)<-[r:CONTAINS_EMOJI]-(p:Payment)
WHERE size((p)-[:CONTAINS_EMOJI]-(:Emoji)) > 1
WITH p, e, CASE
 WHEN e.negativeRatio < e.positiveRatio > e.neutralRatio THEN 1
 WHEN e.negativeRatio < e.neutralRatio > e.positiveRatio THEN 0
 WHEN e.neutralRatio < e.negativeRatio > e.positiveRatio THEN -1
 END as sentiments
WITH p, sum(sentiments) as sentimentScore
RETURN p.note, sentimentScore
ORDER BY sentimentScore ASC LIMIT 20;
//Notes: Results are taxes, sad faces, caffeine-free coffee - unusual one is baseball and tickets?

//Find most neutral combinations
MATCH (e:Emoji)<-[r:CONTAINS_EMOJI]-(p:Payment)
WHERE size((p)-[:CONTAINS_EMOJI]-(:Emoji)) > 1
WITH p, e, CASE
 WHEN e.negativeRatio < e.positiveRatio > e.neutralRatio THEN 1
 WHEN e.negativeRatio < e.neutralRatio > e.positiveRatio THEN 0
 WHEN e.neutralRatio < e.negativeRatio > e.positiveRatio THEN -1
 END as sentiments
WITH p, sum(sentiments) as sentimentScore
WHERE sentimentScore = 0
RETURN p.note, sentimentScore LIMIT 20;
//Notes: Some really weird and hilarious results
