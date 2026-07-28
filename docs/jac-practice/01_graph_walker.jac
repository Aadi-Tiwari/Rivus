"""Practice 1: nodes, typed edges, walker traversal. Expect greeted = Alice, Bob, Dave."""

node Person { has name: str; }
edge Friend {}
edge Coworker {}

walker Greeter {
    has greeted: list = [];
    can greet with Person entry {
        self.greeted.append(here.name);
        visit [->:Friend:->] else {
            print("dead end at", here.name);
        }
    }
}

with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    carol = Person(name="Carol");
    dave = Person(name="Dave");

    alice +>: Friend() :+> bob;
    alice +>: Coworker() :+> carol;
    bob +>: Friend() :+> dave;

    w = Greeter();
    w spawn alice;
    print("greeted:", w.greeted);
}
