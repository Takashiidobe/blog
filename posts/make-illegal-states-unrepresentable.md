---
title: "Make Illegal States Unrepresentable"
date: 2021-10-13T17:09:23-05:00
draft: true
---

# Make Illegal States Unrepresentable

It's important to make states that cause an error unrepresentable. A user interface that affords the user to do something that it shouldn't is a buggy user interface. Likewise, programs that are not expressiveness enough to model the task at hand, or are too expressive are buggy. It's only a matter of time before something bad happens.

## A Simple Example

Let's say we're designing a simple game: `Walk Simulator`. There's a 2 dimensional plane where the main character simply walks from the left to the right. The user is allowed to change one setting: the speed of the character. How should we model this?

First, let's think about what would be clearly wrong: a string, or object. Speed is numeric, so we should use some numeric type to represent it.

Next: Can speed be negative? We could allow this: If the speed is set to a negative number, maybe the character could walk from right to left. We ask our design team, but they want an MVP where the character can only move from left to right.

Let's say our team also wants only whole numbers, for simplicity. What type should we use to model this variable? An unsigned type, of course. Our game does not want us to allow for fractional numbers, so there's no point in having floating point numbers, and signed numbers would also be too expressive, there's no need to have negative numbers.

By choosing an unsigned type, our compiler can reject invalid numbers, and we get it this for free. If you work in a language without unsigned types (like Javascript) you would need to do a check at runtime, like this:

```{.js .numberLines}
function setSpeed(speed) {
  // make sure this is a number
  if (typeof speed !== 'number') throw new Error("The speed provided was not a number.");
  // make sure the number is positive.
  if (speed < 0) throw new Error("The speed provided must be positive.");
  // Floor the number provided to remove floating point parts
  this.speed = Math.floor(speed);
}
```

In Rust, for example:

## Calculator Example

```{.cc .numberLines} 
#include <iostream>

// make illegal states illegal to represent.

class Node {
public:
  virtual ~Node(){};
  virtual int evaluate() const = 0;
};

class OpNode : public Node {
public:
  OpNode(const Node *left, const Node *right) : left(left), right(right) {}
  virtual ~OpNode() {}

protected:
  const Node *left;
  const Node *right;
};

class MulNode : public OpNode {
public:
  virtual ~MulNode() {}
  MulNode(const Node *left, const Node *right) : OpNode(left, right) {}
  int evaluate() const override { return left->evaluate() * right->evaluate(); }
};

class ValueNode : public Node {
public:
  virtual ~ValueNode() {}
  ValueNode(int val) : val(val) {}
  int evaluate() const override { return val; }

private:
  int val;
};

class AddNode : public ONode {
public:
  virtual ~AddNode() {}
  AddNode(Node *left, Node *right) : OpNode(left, right) {}
  int evaluate() const override { return left->evaluate() + right->evaluate(); }
};

int main() {
  const Node *left_val = new AddNode(new ValueNode(5), new ValueNode(5));
  const Node *right_val = new MulNode(new ValueNode(5), new ValueNode(5));
  const Node *total = new MulNode(left_val, right_val);
  std::cout << total->evaluate() << std::endl;
}
```
