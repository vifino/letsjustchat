# Lets just Chat Protocol Docs

# Connecting

To connect, you start a web socket client with the server host and port at path `/ws`, with optional query arguments `name` and `chan`.

When one of the optional query arguments aren't given, the server will choose them.

Example:

``` bash
wscat "ws://server.tld/ws?name=bob"
```

# Protocol
## General

`command arguments and more`

This protocol is command based.

There are two parts to a message: Command and Arguments.

The command, like `msg` is the type of action to apply given arguments.

The arguments are self explanatory, just simple text.

## Sending part

### `msg Hello world!`

Simple message command, sends out "Hello world!" in the current channel.

## Receiving part

### `msg bob hi`

This is, like above, a message, but on the receiving end. `bob` is the name of the sender, which contains no spaces. The rest is the message.

### `join bob`

This means `bob` joined.

### `left bob`

`bob` left the channel.

