---
title: "Learning Recursion"
date: 2021-06-03T11:30:55-04:00
draft: false
---

It's been said that the only way to learn recursion is to learn recursion. So let's get started!

Recursion is defined by the repeated application of a procedure. There are three distinct parts to creating a recursive function:

1. A terminating base case
2. Continuing the recursion
3. Making progress towards the base case

Let's look at all of them while applying them to a problem:

> Given an array of integers, return the sum of their values.

## A terminating base case

We need a terminating base case, because otherwise a recursive function will continue forever.

We'll start backwards (trying to find the case that terminates the algorithm) and work our way from there.

Let's say we have an empty array: well, that would look like this:
If the array is empty, then it makes sense that its sum is 0.

Let's start writing some code to express that:

```{.c .numberLines}
int sum_empty_arr(int arr*, size_t len) {
  return 0;
}

int sum(int arr*, size_t len) {
  if (len == 0) {
    return sum_empty_arr(arr, len);
  } else {
    // In the next section!
  }
}
```

And hey, that's the only base case.

## Continuing the Recursion

To continue the recursion, let's continue thinking: if we have a one item array, what do we do?

A one item array's sum can be expressed like this:

`arr[0] + 0`.

Let's take `{1, 2}` as our array. Well, the sum of the array `{1, 2}` can be expressed like this:

`arr[0] + sum({2})`

Similarly, if we have a 3 item array like `{1, 2, 3}`, the sum of the array can be expressed like this:

`arr[0] + sum({2, 3})`

This formula works on arrays with any length.

Our key insight here is to take the first item of the array, and sum it with the result of the sum of the rest of the items in the array. We've found a way to continue the recursion.

Next, we'll have to think about how to make progress towards the base case.

## Making progress towards the base case

In our formula, we've found a way to continue the recursion. But are we making progress towards the base case?

Our base case will terminate when it is provided an array with a length of 0.

In every recursive call, we reduce the length of the array we provide to `sum` by 1. Thus, as long as our array length is positive (which we can safely assume), we'll make progress towards the base case. Nice! We won't recurse forever.

## Implementation

We can turn our idea into code like so (I'm doing a bit of pointer arithmetic to move the pointer past the first item and decrementing the length before calling `sum` again).

```{.c .numberLines}
int sum(int *arr, size_t len) {
    if (len == 0) {
        return sum_empty_arr(arr, len);
    }  else {
        int head = arr[0];
        len--; // decrement the length
        arr++; // move past the first item
        return head + sum(arr, len);
    }
}
```

And hey, if we run it:

```{.c .numberLines}
int main(void) {
    int arr[] = {1,2,3,4};
    int total = sum(arr, 4);

    printf("%d\n", total); // 10
}
```

And we get the correct result.

We can clean this code up a bit:

```{.c .numberLines}
int sum(int *arr, size_t len) {
    if (len == 0) {
        return 0;
    }  else {
        return arr[0] + sum(++arr, --len);
    }
}
```

Interestingly enough, even though python has a slicing operator, the implementation is similar in length:

```{.py .numberLines}
def list_sum(arr):
  if len(arr) == 0:
    return 0
  else:
    return arr[0] + list_sum(arr[1:])
```

Similarly, in a language like OCaml, where recursion is the idiomatic way to express algorithms:

```{.ml .numberLines}
let rec sum = function
  | [] -> 0 (* if the array is empty, return 0 *)
  | h::t -> h + (sum t) (* otherwise, return the value of the head + sum of the rest of the elements. *)
```

Let's try another problem:

> Given a binary tree, calculate the sum of the values of all nodes in the binary tree.

Let's go through the steps again.

## Finding a base case

Let's ask ourselves what the possible cases are:

If there is no node, because the node is null, clearly it shouldn't count. Much like in the empty array case, let's return 0.

If there is a node, let's return its value.

Great, we've got all our base cases covered. Let's express them before we continue on:

```{.c .numberLines}
int sum(TreeNode *node) {
  if (node == NULL)
    return 0;
  else
    return node->val;
}
```

But how do we continue the recursion?

## Continuing the Recursion

To continue the recursion, we can apply the function we've created to its left and right node. But how? Well, thinking back to the previous problem, the sum of an array is the sum of the current value (the head) + the rest of the items in the array. Likewise, for a binary tree, we need to find the sum of the left items and the sum of the right items.

Since we know that a null node can't point to anything, we can leave that case be, and express the sum of the binary tree as its current value + the sum of its left child + the sum of its right child.

Let's do that:

```{.c .numberLines}
int sum(TreeNode *node) {
  if (node == NULL)
    return 0;
  else
    return node->val + sum(node->left) + sum(node->right);
}
```

## Making Progress

Are we making progress? We must be: for every node, we move onto its child nodes. Child nodes (hopefully) eventually return null, in the case of a finite binary tree (of course, we can't calculate the sum of an infinitely large binary tree).

We did it! We can take this same idea and apply it to linked lists and graphs as well. That'll be an exercise for the reader, but the idea is very similar.

## Appendix

Full code to sum of the nodes of a binary tree:

In C:

```{.c .numberLines}
#include <stdio.h>

typedef struct TreeNode {
  int val;
  struct TreeNode *left;
  struct TreeNode *right;
} TreeNode;

int sum(TreeNode *node) {
  if (node == NULL)
    return 0;
  else
    return node->val + sum(node->left) + solve(node->right);
}
```

In Java:

```{.java .numberLines}
class Solution {
  record TreeNode(int val, TreeNode left, TreeNode right) {}

  public int sum(TreeNode node) {
    if (node == null) {
      return 0;
    } else {
      return node.val + sum(node.left) + sum(node.right);
    }
  }
}
```
In OCaml:

```{.ml .numberLines}
type 'a tree =
  | Node of 'a tree * 'a * 'a tree
  | Leaf;;

let rec fold_tree f a t =
    match t with
      | Leaf -> a
      | Node (l, x, r) -> f x (fold_tree f a l) (fold_tree f a r);;
```
