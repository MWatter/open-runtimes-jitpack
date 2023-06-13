import Vapor
import Foundation

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)

app.on(.GET, "", body: .stream, use: execute)
app.on(.GET, "**", body: .stream, use: execute)
app.on(.POST, "", body: .stream, use: execute)
app.on(.POST, "**", body: .stream, use: execute)
app.on(.PATCH, "", body: .stream, use: execute)
app.on(.PATCH, "**", body: .stream, use: execute)
app.on(.PUT, "", body: .stream, use: execute)
app.on(.PUT, "**", body: .stream, use: execute)
app.on(.DELETE, "", body: .stream, use: execute)
app.on(.DELETE, "**", body: .stream, use: execute)
app.on(.OPTIONS, "", body: .stream, use: execute)
app.on(.OPTIONS, "**", body: .stream, use: execute)

func execute(req: Request) async throws -> Response {
    if !req.headers.contains(name: "x-open-runtimes-secret")
        || req.headers["x-open-runtimes-secret"].first != ProcessInfo.processInfo.environment["OPEN_RUNTIMES_SECRET"] {
        return Response(
            status: .internalServerError,
            body: .init(string: "Unauthorized. Provide correct \"x-open-runtimes-secret\" header.")
        )
    }

    let bodyString = req.body.string ?? ""
    var body = bodyString as Any
    var headers = [String: String]()
    let method = req.method.string
    let scheme = req.uri.scheme!
    let host = req.uri.host!
    let port = req.uri.port!
    let path = req.uri.path
    let queryString = req.uri.query
    var query = [String: String]()
    
    if let queryString = queryString {
        for param in queryString.split(separator: "&") {
            let parts = param.split(separator: "=", maxSplits: 1)
            
            var key: String? = nil
            var value: String? = nil
            
            if parts.isEmpty {
                continue
            }
            if parts.count >= 1 {
                key = String(parts[0])
            }
            if parts.count == 2 {
                value = String(parts[1])
            }
            
            query[key!] = value ?? ""
        }
    }
    
    var url = "\(scheme)://\(host)"
    
    if (scheme == "http" && port != 80) || (scheme == "https" && port != 443) {
        url += ":\(port)"
    }
    
    url += path
    
    if !((queryString ?? "").isEmpty) {
        url += "?"
        url += queryString!
    }
    
    for header in req.headers {
        let key = header.name.lowercased()
        if !key.starts(with: "x-open-runtimes-") {
            headers[key] = header.value
        }
    }

    let contentType = req.headers["content-type"].first ?? "text/plain"
    if contentType.starts(with: "application/json"),
        !bodyString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty,
        bodyString != "\"\"" {
            body = try JSONSerialization.jsonObject(
                with: bodyString.data(using: .utf8)!,
                options: .allowFragments
            ) as Any
    }

    let request = RuntimeRequest(
        bodyString: bodyString,
        body: body,
        headers: headers,
        method: method,
        url: url,
        scheme: scheme,
        host: host,
        port: port,
        path: path,
        queryString: queryString,
        query: query
    )
    
    let response = RuntimeResponse()
    
    let context = RuntimeContext(
        request: request,
        response: response
    )

    var output: RuntimeOutput

    do {
        output = try await annotateError(try await main(context: context))
    } catch {
        context.error(error)
        output = context.res.send("", statusCode: 500)
    }

    var outputHeaders = HTTPHeaders()
    for header in output.headers {
        let key = header.key.lowercased()
        if !key.starts(with: "x-open-runtimes-") {
            outputHeaders.add(name: key, value: header.value)
        }
    }

    var logs = context.logs.joined(separator: "\n")
    logs = logs.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? logs

    var errors = context.errors.joined(separator: "\n")
    errors = errors.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? errors

    outputHeaders.add(name: "x-open-runtimes-logs", value: logs)
    outputHeaders.add(name: "x-open-runtimes-errors", value: errors)
    
    let code: HTTPResponseStatus = .custom(code: UInt(output.statusCode), reasonPhrase: "")
    let resBody: Response.Body = .init(string: output.body)
    
    return Response(
        status: code,
        headers: outputHeaders,
        body: resBody
    )
}

try app.run()
