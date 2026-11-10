#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Size and free space of the volume containing a path (statvfs).
public enum FileSystemSpace {
    public static func capacity(at path: String) throws -> Capacity {
        var volume_Stats = statvfs()
        guard statvfs(path, &volume_Stats) == 0 else {
            throw SampleReadError.unreadable(path: path)
        }
        let block_Bytes = UInt64(volume_Stats.f_frsize)
        let total_Bytes = UInt64(volume_Stats.f_blocks) * block_Bytes
        let available_Bytes =
            UInt64(volume_Stats.f_bavail)
            * block_Bytes
        let used_Bytes =
            total_Bytes - min(available_Bytes, total_Bytes)
        return Capacity(
            used_Bytes: used_Bytes,
            total_Bytes: total_Bytes
        )
    }
}
