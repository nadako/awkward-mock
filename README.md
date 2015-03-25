# What? Mock!

An quick and dirty example of how to easily mock methods in Haxe, with support for static targets (tested on C#).

Maybe I'll make a lib out ouf this, but for now this is a playground for experimenting with human-friendly unit-testing setups.

# How? Awkwardly!

For JS it's quite simple: we always can change a method with `Reflect`.

For C# it works in two phases:
 1. compile with `--no-output` and collect all `mockMethod` calls, saving which methods were mocked on what classes.
 2. compile normally adding `--macro Mock.apply()` that will read the list of mocks saved by previous phase and apply
 build macros for relevant classes, marking mocked methods with `dynamic` (so they can be overriden in runtime).
