---
title: "Making Choices"
date: 2021-07-07T13:10:44-04:00
draft: true
---

How do we assess decisions? How do we pick from A and B? How do we make the right decision? These are all questions we have from time to time, and the subject of today's post. 

## Go with your Gut (use a heuristic)

There's a school of people who "go with their gut" or make decisions with little evidence. There's nothing wrong with this per se, but it requires some context. It is not bad to go with your gut on choices that a) don't matter in the long run or b) can be easily fixed in the future, i.e. "What should I have for lunch today" or "I'm not sure if I should buy a white shirt or a blue shirt" when the store you're buying from has an exchange policy. In the case that a decision fits under the above points, you should always go with your gut; spending more time making a decision is a waste of time, and going with your gut short-circuits the brain's process of making decisions.

There's another caveat here; you should go with your gut if the quality of data you can accumulate to aid in your decision making is low. For example, imagine a game where I could tell you to pick between X and Y, with X and Y being two financial instruments. You have $1,000 dollars to invest in either (but not both) of them. I give you no other information, and there is no way to gather credible information about either. In this case, going with your gut or randomness is warranted, since the optimal choice is a mixed strategy of choosing X 50% of the time, and B 50% of the time.

### Data lies

Let's talk about the case when you have no credible information. Assume you're Microsoft, trying to market the Xbox One at a specific price, and competing with Sony's PS5 that is also planned to launch at the same time as your console. We have one decision to make -- how to price. Since your company and Sony are the only companies that sell comparable goods, you want to price your console at a tiny bit less than your competitor's. Doing so will get most potential buyers who aren't loyal to the other company. You could make off like a bandit, get a nice stock bonus, and retire to a beachfront property in the bahamas, and never work a day more in your life... Oh right, back to real life. Anyway, your goal is to price your console just below your competitor's. But there was a leak last week from a credible source that said they wanted to sell their console at $479. You could hypothetically launch a marketing campaign selling your console for $450 and beat them to the punch. That beachfront property isn't far now... Focus. Unfortunately, you have no idea to verify that this is true. Who knows, maybe the competitor "leaked" this information out themselves just to get you to bite.

In this story you do have an alternative; you can try to make a backroom deal with your competitor and both agree to sell the console for the same higher than market price and execs from both companies can retire afterwards, lining their pockets with money. Of course that's illegal, so you'd more likely than not be enjoying jail instead. 

Even if it wasn't illegal, you'd actually still be stuck in a quandary. Because both you and your competitor can capture more of the market by lying in the backroom and then dropping prices for consumers, an artificially high price isn't attainable when there's more than one seller for a good in a market. In the backroom, the competitor could lie to you, say they pinky swear that they'll sell their console for $600 and then renege when they feel the iron is hot and laugh their way to the bank. They could also set you up and send you to jail, so that's even better.

In this story, no matter what data each company gets, they can't ever trust it, so they go with their gut. No one goes to jail, no one goes to the bahamas.

### When the gut fails

There are some times when going with your gut fails though. Texas Hold'em poker is a game known for cowboy hats and reading bluffs. Players are given 2 cards in their hand and 5 common community cards are revealed interspersed with periods of betting to capture the pot (the amount of money all players bet) each round. 

You'd think in this sport that reading faces would be all you'd need to do. Shockingly, no. 

While the game is fairly chaotic and *somewhat* luck based, the game is easy to solve when there are only two players, and both players are given a long set of hands to play. Just use some game theory.

Most of the old guard in poker relied on reading each other's minds, based on the shuffling of opponents cards, or building a mental heuristic based on how they played previous hands (some players are more aggressive than others, and others are more conservative).

Doug Polk, a (at the time) broke college student used game theory to win himself millions of dollars in the Texas Hold'em scene and retire. Even though you have incomplete information (you have no idea what two cards your opponent might have) you can calculate the optimal way to play each hand based off of the cards you are given and the community cards on the table, regardless of the cards your opponent has. You make your judgments based off of the strength of your hand and the community cards and also of the aggressiveness of your opponents bets. With this information in tow, Doug Polk turned to his computer and figured out the optimal mixed strategies of playing each hand with a given set of community cards, and won enough money to retire shortly after.

Sometimes all the data you need is right in front of you, and you still choose to go with your gut. That can be a bad decision, when it's consequential and is repeated frequently.

## Using Data

Assuming we can glean some data about the problem at hand and our data is useful, we move onto a category of problems where you need to make a decision based off of said data. To focus our comparison, we will ignore choices that are uneven and instead focus on situations where choices we could make are roughly of the same utility, and talk about some frameworks to do so.


