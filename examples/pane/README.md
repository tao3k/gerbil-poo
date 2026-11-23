# Live Inspector pane

[Pane and Inspector classes](pane.ss) share typed layout slots. The separate
[theme extension](theme.ss) contributes a `shared-initialize :after` method
that accepts `theme:`. An app can install the method bundle and open a request
trace in the existing pane.

```sh
gerbil test examples/t/pane
```

The [runnable case](../t/pane/pane-test.ss) creates a dark pane at width 120 and
reconfigures it to light. It migrates the same object to InspectorPane,
keeps the theme and width, and reads the multiple-inheritance order.
Terminal rendering combines class and target specializers with
`call-next-method` and an around method.

The event generic dispatches on both the pane and the event class. A resize
changes the width to 132, and selecting a section shows the trace timeline.
A resize to 500 fails the Width contract and the pane retains its current
layout and selection.

The scenario follows DUIM's extensible pane and event protocols.
[Open Dylan DUIM gadgets](https://opendylan.org/duim-reference/gadgets.html)
