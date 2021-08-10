//Data sources:
//Venmo - https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/venmo-payments
//Emojis - https://raw.githubusercontent.com/moxious/emoji-graph

//Venmo Data:

//Create Applications, Payments and connect with relationship
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/venmo-payments/venmo_demo.csv' AS line
MERGE (app:Application {applicationId: line.`app.id`})
ON CREATE SET app.name = line.`app.name`, app.description = line.`app.description`, app.imageURL = line.`app.image_url`
WITH line, app
MERGE (pay:Payment {paymentId: line.`payment.id`})
ON CREATE SET pay.audience = line.audience, pay.dateCreated = datetime(line.`payment.date_created`), pay.status = line.`payment.status`, pay.note = line.`payment.note`, pay.action = line.`payment.action`, pay.type = line.type, pay.dateComplete = CASE WHEN coalesce(line.`payment.date_completed`,"") = "" THEN null ELSE datetime(line.`payment.date_completed`) END
WITH line, app, pay
MERGE (pay)-[r2:PAID_USING]->(app)
RETURN count(*);

//Create paying User, find loaded Payment and connect with relationship
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/venmo-payments/venmo_demo.csv' AS line
MERGE (from:User {userId: line.`payment.actor.id`})
ON CREATE SET from.isBlocked = line.`payment.actor.is_blocked`, from.dateJoined = datetime(line.`payment.actor.date_joined`), from.about = line.`payment.actor.about`, from.displayName = line.`payment.actor.display_name`, from.firstName = line.`payment.actor.firstName`, from.lastName = line.`payment.actor.last_name`, from.profilePicURL = line.`payment.actor.profile_picture_url`, from.isGroup = line.`payment.actor.is_group`, from.username = line.`payment.actor.username`
WITH line, from
MATCH (pay:Payment {paymentId: line.`payment.id`})
MERGE (from)-[r:SENDS]->(pay)
RETURN count(*);

//Create paid User, find loaded Payment and connect with relationship
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/JMHReif/graph-demo-datasets/main/venmo-payments/venmo_demo.csv' AS line
MERGE (to:User {userId: coalesce(line.`payment.target.user.id`, 'unknown')})
ON CREATE SET to.firstName = line.`payment.target.user.first_name`, to.dateJoined = CASE WHEN coalesce(line.`payment.target.user.date_joined`,"") = "" THEN null ELSE datetime(line.`payment.target.user.date_joined`) END, to.isGroup = line.`payment.target.user.is_group`, to.lastName = line.`payment.target.user.last_name`, to.isActive = line.`payment.target.user.is_active`, to.isBlocked = line.`payment.target.user.is_blocked`, to.profilePicURL = line.`payment.target.user.profile_picture_url`, to.about = line.`payment.target.user.about`, to.username = line.`payment.target.user.username`, to.displayName = line.`payment.target.user.display_name`
WITH line, to
MATCH (pay:Payment {paymentId: line.`payment.id`})
MERGE (pay)-[r3:PAID_TO]->(to)
RETURN count(*);

//Emoji Data:

CREATE INDEX ON :Emoji(name);
CREATE INDEX ON :Emoji(column_a);
CREATE INDEX ON :Emoji(browser);
CREATE INDEX ON :Emoji(code);
CREATE INDEX ON :Category(name);

//Raw Category list as a starting point
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/moxious/emoji-graph/master/category.csv' as line
MERGE (c:Category { name: apoc.text.replace(toLower(line.category), '_', '-') })
   SET c.synthetic = false
RETURN count(c);

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/moxious/emoji-graph/master/emojis-rawcsv/all-emojis.csv' as line
WITH line
WHERE line.code is not null
MERGE (e:Emoji { emoji: line.browser })
  ON CREATE SET
    e.code = line.code,
    e.name = line.cldr_short_name,
    e.column_a = line.column_a,
    e.rawSet = true
MERGE (c:Category { name: apoc.text.replace(toLower(line.category), '_', '-') })
   SET c.synthetic = false
MERGE (e)-[:IN]->(c)
RETURN count(e);

//Emoji Database
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/moxious/emoji-graph/master/emoji-database/emoji-database.csv' as line
MERGE (e:Emoji { emoji: line.emoji })
  ON MATCH SET e.altName = coalesce(line.name, '')
  ON CREATE SET e.name = coalesce(line.name, '')
  SET e.codepoints = line.codepoints, e.emojiDatabase = true
MERGE (g:Category { name: apoc.text.replace(toLower(line.group), '_', '-') })
   SET g.emojiDatabase = true, g.synthetic = false
MERGE (sg:Category { name: apoc.text.replace(toLower(line.sub_group), '_', '-') })
   SET sg.emojiDatabase = true, sg.synthetic = false
MERGE (sg)-[:SIMILAR]->(g)
MERGE (e)-[:IN]->(sg)
RETURN count(e);

//Sentiment
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/moxious/emoji-graph/emoji-sentiment/sentiment/Emoji_Sentiment_Data_v1.0.csv'
AS line
//Headers: Emoji,Unicode codepoint,Occurrences,Position,Negative,Neutral,Positive,Unicode name,Unicode block
MERGE (e:Emoji { emoji: line.Emoji })
SET 
    e.codepoint = line.`Unicode codepoint`,
    e.occurrences = toInteger(line.Occurrences),
    e.position = toFloat(line.Position),
    e.negative = toInteger(line.Negative),
    e.neutral = toInteger(line.Neutral),
    e.positive = toInteger(line.Positive),
    e.unicodeName = toLower(line.`Unicode name`),
    e.sentiment = true
MERGE (c:Category { name: apoc.text.replace(toLower(line.`Unicode block`), '_', '-') })
   SET c.synthetic = false
MERGE (e)-[:IN]->(c)
return count(e);

//Compute a "positive/negative" ratio of usage
MATCH (e:Emoji)
WHERE e.sentiment
WITH e, 
 toFloat(e.positive) / toFloat(e.occurrences) as positiveRatio,
 toFloat(e.negative) / toFloat(e.occurrences) as negativeRatio,
 toFloat(e.neutral) / toFloat(e.occurrences) as neutralRatio
SET 
  e.positiveRatio = positiveRatio,
  e.negativeRatio = negativeRatio,
  e.neutralRatio = neutralRatio
RETURN count(e);

//Create similar relationships between emojis
MATCH (e:Emoji)
MATCH (e2:Emoji)
WHERE id(e) < id(e2)
AND substring(e.codepoints,0,4) = substring(e2.codepoints, 0, 4)
WITH e, e2
MERGE (e)-[r:SIMILAR]->(e2)
RETURN count(*);

//Category Similarity
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/moxious/emoji-graph/master/similar.csv' as line
MERGE (a:Category { name: apoc.text.replace(toLower(line.categoryA), '_', '-') })
MERGE (b:Category { name: apoc.text.replace(toLower(line.categoryB), '_', '-') })
MERGE (a)-[r:SIMILAR]->(b)
RETURN count(r);

//Combine (relationship between data sets)
CALL apoc.periodic.iterate(
    'MATCH (e:Emoji) RETURN e', 
    'MATCH (p:Payment) WHERE p.note CONTAINS e.emoji MERGE (p)-[r:CONTAINS_EMOJI]->(e) RETURN count(*)',
    {batchSize: 50, iterateList:false})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;

//Set a predominant sentiment for the emoji
MATCH (e:Emoji)
WHERE e.sentiment
WITH e, CASE
 WHEN e.negativeRatio < e.positiveRatio > e.neutralRatio THEN 'positive'
 WHEN e.negativeRatio < e.neutralRatio > e.positiveRatio THEN 'neutral'
 WHEN e.neutralRatio < e.negativeRatio > e.positiveRatio THEN 'negative'
 ELSE null END as leadSentiment
SET e.leadSentiment = leadSentiment
RETURN count(*);