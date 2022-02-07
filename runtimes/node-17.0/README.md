# Node Runtime 17.0

This is the Open Runtime that builds and runs NodeJS code based on a `node:17-alpine` base image. 

The runtime itself uses [Micro](https://github.com/vercel/micro) as the Web Server to process the execution requests.

# Usage

Clone the repository:

```bash
git clone https://github.com/open-runtimes/open-runtimes.git
```

Enter the node runtime folder:

```bash
cd open-runtimes/runtimes/node-17.0
```

Run the included example cloud function:

```bash
docker-compose up -d
```

You can now send `POST` request to `http://localhost:3000`. Make sure you have header `x-internal-challenge: example1234`, and JSON body `{ "path": "/usr/code", "file": "index.js" }`.

You can also make changes to the example code and apply the changes with the `docker-compose restart` command.

# Notes

When writing functions for this runtime , ensure they are exported directly through the `module.exports` object.

An example of this is:

```js
module.exports = (req, res) => {
    res.send('Hello World!');
}
```

The res object has two methods:
`send`: Send a string response to the client.
`json`: Send a JSON response to the client.

An example of the `json` method looks like this:

```js
module.exports = (req, res) => {
    res.json({
        'normal': 'Hello World!',
        'env1': req.env['ENV1'],
        'payload': req.payload
    });
}
```

Internally the request body sent to the runtime and all runtimes looks like so:

```json5
{
    "path": "/usr/code",
    "file": "index.js",

    // following will be exposed to the function
    "env": {
        // env variables
    },
    "payload": {
        // payload
    },
    "headers": {
        // headers
    }
}
```