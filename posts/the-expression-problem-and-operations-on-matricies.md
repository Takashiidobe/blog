---
title: "The Expression Problem And Operations On Matricies"
date: 2021-06-22T08:52:01-04:00
draft: false 
---

I've heard the sentiment that technical interviews focus on the wrong things; technical aptitude in data structures and algorithms isn't a great measure of people's on the job performance. I agree. That being said, there are some small problems where cursory knowledge in them can help you out.

I'm going to use an example I encountered recently, where I wanted to aggregate my personal finances into monthly, quarterly, and yearly reports, with columns for earnings, spend, and cashflow (earnings - spend). 

I downloaded the relevant CSVs and went to work parsing them.

## Parsing

The first problem came with cleaning up some transactions that were unnecessary -- banks tend to charge a maintenance fee, but they end up crediting you if you meet certain criteria. Even though this balances out, I didn't want this to count in my earnings and spend, so I wrote a `sed` regex to delete these lines. Likewise, I wanted to remove some of my investments that I had made (I don't consider these to be spending, and I wanted to track these another way). Another `sed` regex it is. Eventually this became a pain, so I made a bash function to combine the regexes in an array to parse the CSV. You just add regexes and it'll remove the related transactions. Easy enough.

## The problem

If you visualize the problem at hand, you'll get this matrix.

|          |      Monthly     | Quarterly          | Yearly          |
|:--------:|:----------------:|--------------------|-----------------|
| Earnings | Monthly Earnings | Quarterly Earnings | Yearly Earnings |
| Spend    | Monthly Spend    | Quarterly Spend    | Yearly Spend    |
| Cashflow | Monthly Cashflow | Quarterly Cashflow | Yearly Cashflow |

We have an (m * n) problem, where if we had a new row or column, we add (m) or (n) more things we need to calculate. 

Let's get solving.

## Naive Approach

The Naive approach is the O(m * n) solution, where you create a function that deals with a particular cell of this matrix. Take Monthly Earnings. You would write a function that does the logic for dividing the CSV into months, and then applying the logic for Earnings to it.

You would repeat this eight times, to get 9 different functions.

When calling this logic, you would have a switch-case that would select the logic required.

This isn't very dry, and very tedious, even with only 9 cells. I wanted something better. This is due to the runtime of matricies.

# The Expression problem

The [expression problem](https://craftinginterpreters.com/representing-code.html#the-expression-problem) is a fundamental problem in writing functions that work on types and vice versa.

OOP Languages like Java make it easy to create new types that have operations on data. But let's say you want to add a new method to all your classes. You now need to add a new method to all of your existing and future classes.

ML type languages use pattern matching, which allows you to easily add new operations to a function. But to apply that operation to all existing types, you have to add a new case to all of the pattern matches. 

Let's say I add a new time period, "bi-yearly" to denote half a year chunks. Well, if we go by the naive case, we'd have to add new cases for bi-yearly + cashflow, bi-yearly + earnings, bi-yearly + spend. That's 3 new functions for one new time period. Ouch.

Let's say I want a new category that only counts purchases that are larger than $100, and call these "large purchases". If so, I would have to add logic to count for monthly, quarterly, bi-yearly, and yearly time periods. That's 4 new functions for a new category.

Let's say I want to add a new dimension. I want to split my purchases for all of the above categories and time periods between my credit card and debit card. That's 4 * 4, or 16 new functions I'd need to implement.

Big O notation would say this grows linearly with regards to the size of each dimension.

If we have 4 monetary categories and 4 time periods, we have 4 * 4 or 16 functions to implement.
If we have 4 monetary categories, 4 time periods, and 2 types of credit cards, we have 4 * 4 * 2, or 32 functions to implement.

Our first proposed matrix is a 2D square, and we're calculating its area. A square with a length of four and a height of 4 has an area of 16.

Our second proposed matrix is a 3D square (a cube). To calculate the area of a cube, you multiply its length, width, and height. We have a length of 4, a width of 4, and a height of 2, totalling 32.

As we add new fields to our rows and columns, and new dimensions to our matrix, we'll soon see that this becomes untenable. (What happens if I also want to count my investment accounts, of which I have many? I'd have to add more and more dimensions, and the amount of functions to implement increases quite a lot.

## Improving the Naive Approach

In the interest of clean code, I wanted to create small composable functions that would calculate the each category.

The Earnings function would only calculate transactions with a positive amount 
The Spend function would only calculate transactions with a negative amount
The Cashflow function would calculate all transactions.

The Monthly function would divide the CSV into months, and apply a function to each range.
The Quarterly function would divide the CSV into quarters, and apply a function to each range.
The Yearly function would divide the CSV into years, and apply a function to each range.

But the problem is how to set this up properly.

We need some way to signal to the main function that we want to calculate a row * column pairing (a cell). If we add a new dimension, we don't want to break previous code.

## Using a pair

One way to signal this is to use a pair of enums that are captured in a pair as (row, col). 
This works well enough if we stick to two dimensions. If we add a 3rd dimension, though, this will create incorrect code. If we're strict on requiring a pair, then we can't add the 3rd dimension at all without breaking all of our existing code. If we're looser (allow any tuple, and unpack the first, second and third values) this will work, but our code will be a bit confusing in order to maintain backwards compatibility (some code will check the first and second fields of a 3-tuple, even though it should be checking all three).

## Using a flag

Another way to signal this is to use a Flag enum. A flag enum is an enum that has values corresponding to powers of 2.

For example:

```{.c .numberLines}
typedef enum Color {
  RED = 1,
  GREEN = 2,
  BLUE = 4
} Color;
```

(Some people prefer to write it like this, to be explicit that this is a flag):

```{.c .numberLines}
typedef enum Color {
  RED = 1 << 0, // 1 
  GREEN = 1 << 1, // 2
  BLUE = 1 << 2, // 4
} Color;
```

This has the nice property that we can use bitwise or to denote more than one state, and bitwise and to check if the enum is one or more or a particular state.

```{.c .numberLines}
Color color = RED | GREEN; // this color is Red and Green
Color Black = RED | GREEN | BLUE; // this color, black, is all the colors

if (color & RED) {
  // this color has red, do some logic in the red case
}
if (color & GREEN) {
  // this color has green, do some logic in the green case
}
if (color & BLUE) {
  // this color has blue, do some logic in the blue case
}
```

In C, since enums are stored as an unsigned int, you can store up to 32 fields (rows + columns + dimensions, in our case). Sometimes this isn't enough, and you'll have to find another way, but in our case, it works fine.

## The final implementation

Finally to solve the problem, we want to provide a flag enum, and get the CSV that we're applying it to. First, we want to slice the CSV into the range provided, and then apply some category (Earning, Spend, Cashflow) to it, and then save the CSV.

That can be done something like this:

```{.c .numberLines}
typedef enum Categories {
  MONTHLY = 1 << 0,
  QUARTERLY = 1 << 1,
  YEARLY = 1 << 2,
  EARNINGS = 1 << 3,
  SPEND = 1 << 4,
  CASHFLOW = 1 << 5,
} Categories;

void generateCsvs(Category category) {
  if (category & MONTHLY) {
    doMonthlyLogic();
  }
  if (category & QUARTERLY) {
    doQuarterlyLogic();
  }
  if (category & YEARLY) {
    doYearlyLogic();
  }
  if (category & EARNINGS) {
    doEarningsLogic();
  }
  if (category & SPEND) {
    doSpendLogic();
  }
  if (category & CASHFLOW) {
    doCashflowLogic();
  }
}
```

We can generate our CSVs just like that. Nice. If we add a new dimension, like Credit card vs debit card, all we have to do is add it to our enum and our main function. This only adds two new enums and two new cases. We've gone from adding (m * n) functions for our logic to just (m + n). Big O strikes again.


```{.c .numberLines}
typedef enum Categories {
  MONTHLY = 1 << 0,
  QUARTERLY = 1 << 1,
  YEARLY = 1 << 2,
  EARNINGS = 1 << 3,
  SPEND = 1 << 4,
  CASHFLOW = 1 << 5,
  CREDIT = 1 << 6,
  DEBIT = 1 << 7,
} Categories;

void generateCsvs(Categories category) {
  if (category & CREDIT) {
    doCreditLogic();
  }
  if (category & DEBIT) {
    doDebitLogic();
  }
  if (category & MONTHLY) {
    doMonthlyLogic();
  }
  if (category & QUARTERLY) {
    doQuarterlyLogic();
  }
  if (category & YEARLY) {
    doYearlyLogic();
  }
  if (category & EARNINGS) {
    doEarningsLogic();
  }
  if (category & SPEND) {
    doSpendLogic();
  }
  if (category & CASHFLOW) {
    doCashflowLogic();
  }
}
```

If we wanted more than 31 categories, we could still do that using a struct instead of an enum. This creates a struct where every member is a boolean flag, and we're checking if it's set in our generateCsvs code.

```{.c .numberLines}
typedef struct Categories {
  int MONTHLY : 1;
  int QUARTERLY : 1; 
  int YEARLY : 1; 
  int EARNINGS : 1;
  int SPEND : 1; 
  int CASHFLOW : 1; 
  int CREDIT : 1; 
  int DEBIT : 1; 
} Categories;

Categories category = { 1, 0, 0, 1 }; // MONTHLY and EARNINGS are set, everything else is zero-initialized.

// or this:
Categories category = {};
category.MONTHLY = 1; // set MONTHLY;
category.EARNINGS = 1; // set EARNINGS; 

void generateCsvs(Categories category) {
  if (category.MONTHLY) {
    doMonthlyLogic();
  }
  // etc.
}
```

## A note on Associativity

But wait, there's something we can improve upon in our solution:

You might've noticed that we're coupling our code based on time. Since we've decided to cut up the CSV first by time and then calculate the monetary category, you've noticed that if we flip the order of them, we might get a different result. This is bad, because refactoring tends to reorder things, and code that is coupled throughout time tends to lead to messier code.

To improve this, we need to add a few restrictions.

But first, a review on associativity and composition.

Associativity means that the order a function is applied in doesn't matter.

Let's take the multiplication function. You'll notice that we can apply them in any order and the function is still correct.

> 4 * 3 * 2 == (4 * 3) * 2 == 4 * (3 * 2)

Whereas division is not associative, because:

> (12 / 2) / 3 != 12 / (2 / 3).

What we did above was like division, where we must apply the functions in some order, so they are coupled in time (the parentheses denote this). What we really want is a mulitiplicative (associative) function, because no matter how many changes we make to the code, it will only grow in complexity linearly, not polynomially.

Thus, if we guarantee that our operations are associative, then we don't have to worry about how we lay out our main function at all.

To do this, we'll have to write our functions in a way that they take a CSV and return a CSV after doing some to work them. These CSVs must work on every other CSV that any other step in the main function can produce. So, we'll change our main function to be like this, where every function takes the CSV and returns a CSV.

We'll use the flag enum to make sure that we're applying just the functions that we want.

```{.c .numberLines}
void generateCsvs(Categories category) {
  csv = {}; 
  // assume the CSV is an array
  if (category & CREDIT) {
    csv = doCreditLogic(csv);
  }
  if (category & DEBIT) {
    csv = doDebitLogic(csv);
  }
  // etc
  writeToCsv(csv);
}
// this is the same function 
void generateCsvs(Categories category) {
  csv = {}; 
  // We've flipped the order, but it still works 
  if (category & DEBIT) {
    csv = doDebitLogic(csv);
  }
  if (category & CREDIT) {
    csv = doCreditLogic(csv);
  }
  // etc
  writeToCsv(csv);
}
```

## Conclusion

We've seen how we can use flag enums, combined with some logic, to cut down the amount of functions we have to write in order to calculate the cell of a matrix. While I won't agree big tech interviews are the best way to assess candidates, sometimes these problems crop up, and people have been grappling with them for a long time (like the expression problem).

