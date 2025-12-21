import Entities
import Foundation

struct JulelysDaemon {
    enum SockErr: Error { case posix(String) }

    static func start(request: (RequestCommand) -> Codable ) async throws {
        let socketPath = "/tmp/julelys.sock"

        unlink(socketPath)

        #if os(Linux)
        let fd = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { throw SockErr.posix("socket(): \(errno)") }

        // Optional: make sure the socket file is world-readable/writable if you want
        umask(0)

        // sockaddr_un must be zeroed
        var addr = sockaddr_un()
        memset(&addr, 0, MemoryLayout<sockaddr_un>.size)

        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy path (NUL-terminated)
        _ = socketPath.withCString { cstr in
            // strncpy ensures we don't overrun sun_path
            strncpy(
                &addr.sun_path.0,
                cstr,
                MemoryLayout.size(ofValue: addr.sun_path)
            )
        }

        // Compute length (Linux): family + path bytes
        // Using full struct size is also acceptable on Linux.
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafeBytes(of: &addr) { raw in
            let sa = raw.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            return bind(fd, sa, addrLen)
        }
        guard bindResult == 0 else { throw SockErr.posix("bind(): \(errno)") }

        listen(fd, 10)
        fputs("🎄 julelys_manage daemon lytter på \(socketPath)\n", stderr)

        // Acceptér forbindelser løbende
        while true {
            var clientAddr = sockaddr()
            var len: socklen_t = socklen_t(
                MemoryLayout.size(ofValue: clientAddr)
            )
            let clientFD = accept(fd, &clientAddr, &len)
            guard clientFD >= 0 else { continue }

            // Læs besked fra klient
            var buffer = [UInt8](repeating: 0, count: 2048)
            let bytesRead = read(clientFD, &buffer, buffer.count)
            guard bytesRead > 0 else {
                close(clientFD)
                continue
            }

            let msg = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
            fputs("📩 Modtog: \(msg)\n", stderr)

            // Behandl JSON request
            let responseData: Data

            do {
                let data = Data(msg.utf8)
                let command = try JSONDecoder().decode(
                    RequestCommand.self,
                    from: data
                )
                
                responseData = try JSONEncoder().encode(request(command))
            } catch {
                let err = [
                    "error": "invalid request: \(error.localizedDescription)"
                ]
                responseData = try! JSONEncoder().encode(err)
            }

            // Skriv JSON-svar tilbage
            _ = responseData.withUnsafeBytes { ptr in
                write(clientFD, ptr.baseAddress, ptr.count)
            }

            close(clientFD)
        }
    }
}
