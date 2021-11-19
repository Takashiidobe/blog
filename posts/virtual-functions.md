---
title: "Virtual Functions"
date: 2021-05-16T21:28:00-04:00
draft: false
---

While learning Java, I came across this line of code:

```{.java .numberLines}
List<Integer> array = new ArrayList();
```

As someone who knows C++, this is somewhat confusing -- `List` is an interface that `ArrayList` implements. But if we treat `ArrayList` as a list, then when we call `List.add()` we must use dynamic dispatch to find the right implementation, since the implementation of `add` isn't on the list interface.

That involves a `virtual` function lookup.

In Java, most function calls are `virtual`, unless a method is declared as `final` (which means it cannot be overriden).

By doing this, we get an advantage -- if we decide to change our `array` variable from an `ArrayList` to another `List` interface conforming type, we can do so without breaking any code.

In exchange, we cannot use any `ArrayList` specific methods without casting to `ArrayList`, which nullifies this benefit.

We have information that both ArrayList and LinkedList implement the List interface, so we can treat them as such in a collection.

```{.java .numberLines}
ArrayList<List> lists = new ArrayList<List>();
lists.add(new ArrayList());
lists.add(new LinkedList());

for (List<Integer> l : lists) {
    l.add(10); // defer to each lists' implementation for add
}
```

Since we know that Java uses virtual functions for interface implementations, everything works as expected. `l.add(10)` defers to the implementation of `ArrayList` and `LinkedList`, and each list is added a `10`.

A full example of virtual functions might look something like this:

```{.java .numberLines}
public class Animal {
  void move() {
    System.out.printf("walk %s\n", this.name());
  }

  String name() {
    return "Animal";
  }

  public static void main(String[] args) {
    Animal animals[] = {new Animal(), new Bird(), new Elephant()};

    for (Animal animal : animals) {
      animal.move();
    }
  }
}

class Bird extends Animal {
  @Override
  void move() {
    System.out.printf("fly %s\n", this.name());
  }

  @Override
  String name() {
    return "Bird";
  }
}

class Elephant extends Animal {
  @Override
  String name() {
    return "Elephant";
  }
}
```

Running this prints this out:

```{.sh .numberLines}
walk Animal
fly Bird
walk Elephant
```

Here we create a base class, `Animal`, which has two methods, `name` and `move`. This class is instantiable because it has default implementations for both methods. The Bird class overrides the move method, since it flies instead of walks, and the Elephant only overrides the name. When we collect them into an array and call the `move()` method on each animal as an animal, Java does the virtual function lookup and calls the correct overriden method as we expect.

It turns out that not every language does this, mainly because there is a runtime cost in dynamic dispatch.

In C++, you must designate a function as `virtual` which labels a function as overridable by an inherited class.

A roughly word for word translation of the above java program would look like this:

```{.cpp .numberLines}
#include <stdio.h>

struct Animal {
  virtual const char *name() const { return "Animal"; }
  virtual void move() const { printf("walk %s\n", name()); }
  virtual ~Animal() {}
};

struct Bird : public Animal {
  virtual void move() const override { printf("fly %s\n", name()); }
  virtual const char *name() const override { return "Bird"; }
};

struct Elephant : public Animal {
  virtual const char *name() const override { return "Elephant"; }
};

int main(void) {
  const Animal *animals[] = {new Animal(), new Bird(), new Elephant()};

  for (const auto &animal : animals) {
    animal->move();
  }
}
```

This returns:

```{.sh .numberLines}
walk Animal
fly Bird
walk Elephant
```

In the Java version it isn't apparent to the programmer that there is a runtime cost, but C++ puts it front and center. Since we used the `new` keyword, everything is placed on the heap. When we try to call the `move()` method, we have to do it with the `->` operator, which calls an object on the heap, rather than on the stack.

Let's say we don't use the `new` operator, and don't use a pointer lookup:

```{.cpp .numberLines}
int main(void) {
  const Animal animals[] = {Animal(), Bird(), Elephant()};

  for (const auto &animal : animals) {
    animal.move();
  }
}
```

This prints out:

```{.sh .numberLines}
walk Animal
walk Animal
walk Animal
```

Since we are literally treating each animal as an `Animal` type, `animal.move()` calls the default `Animal` implementation of move. If we choose to have no runtime cost, we get less desirable behavior. But C++ gives you the choice upfront.

Let's dig deeper.

C doesn't have any language support for `virtual` functions, but we can still emulate them.

A (very) rough translation of the java program might look like this:

```{.c .numberLines}
#include <stdio.h>

typedef struct Animal {
  const char *name;
  void (*move)(const struct Animal *);
} Animal_t;

void fly(const Animal_t *a) { printf("fly %s\n", a->name); }
void walk(const Animal_t *a) { printf("walk %s\n", a->name); }
void animal_move(const Animal_t *a) { a->move ? a->move(a) : walk(a); }

int main(void) {
  const Animal_t animals[] = {
      {.name = "Animal"}, {.name = "Bird", .move = fly}, {.name = "Elephant"}};
  const size_t animals_len = sizeof(animals) / sizeof(Animal_t);

  for (int i = 0; i < animals_len; i++) {
    const Animal_t animal = animals[i];
    animal_move(&animal);
  }
}
```

C actually lets us do some interesting things here: It allows us to allocate our `animals` on the stack. As well, we create an `animal_move` function that asks the struct passed in if it has a function pointer for `move`. If it does, then it defers to that, otherwise it calls a default implementation. If we do choose to use a more specific version of `move`, then we do have the pointer lookup cost, but if not, there is no cost.

Predictably, this prints:

```{.sh .numberLines}
walk Animal
fly Bird
walk Elephant
```

Digging a little up, we find that Rust has a similar concept, but it does away with using keywords like `virtual` or `final` to designate dynamic dispatch.

```{.rs .numberLines}
pub trait Animal {
    fn name(&self) -> String {
        "Animal".to_string()
    }
    fn act(&self) {
        println!("walk {}", self.name());
    }
}

struct GenericAnimal {}
impl Animal for GenericAnimal {}

struct Bird {}
impl Animal for Bird {
    fn name(&self) -> String {
        "Bird".to_string()
    }
    fn act(&self) {
        println!("fly {}", self.name());
    }
}

struct Elephant {}
impl Animal for Elephant {
    fn name(&self) -> String {
        "Elephant".to_string()
    }
}


fn main() {
    let animals: Vec<&dyn Animal> = vec![&GenericAnimal{}, &Bird{}, &Elephant{}];
    for animal in animals {
        animal.act();
    }
}
```

We create a `trait` of animal (kind of like an interface, but supercharged) and then we create an instantiable version of it (`GenericAnimal`) that just takes the default implementation.
Then we implement our `Bird` and `Elephant` and we collect them into a vector and properly call the method on them. The compiler assumes that we want dynamic dispatch by default and does it for us. If not, we can call the parent classes' method:

```{.rs .numberLines}
Animal::act(&Bird); // this calls the Animal version of `act` with a bird.
```

This is similar to C++:

```{.cpp .numberLines}
const Bird* bird = new Bird();
bird->Animal::move(); // calls Animal::move with bird.
```

In short, here's a history of virtual functions and their syntax, starting from C and ending with Rust:

In C, there's a rough way to emulate virtuals, but it takes some effort since it's not built into the language.

In C++, virtual functions were deemed useful enough to be built into the language. This led to a terser syntax for overriding, but led to more cognitive load on the programmer, since they had to choose `virtual` or non-virtual implementations.

In Java, most methods are by default virtual, so the implementation details are hidden from the programmer. Java allows you to declare non-overridable methods as `final`, so `final` methods have no runtime cost, and all `@Override` methods have runtime cost, which is a fair tradeoff.

In Rust, the compiler figures out if you want a `virtual` or normal method call through your trait implementations, but allows you to call the base method through a subclass if you so choose. This allows for having even less cognitive load than in Java (no `@Override` or `final` necessary), but with an escape hatch to call the base class method in an overriden type (as C++ allows).
