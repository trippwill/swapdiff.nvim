---@meta
---@mod swapdiff.auxtypes Auxiliary Types for SwapDiff

---@class NvimSwapInfo
---@field version string Vim version
---@field user string User name
---@field host string Host name
---@field fname string Original file name
---@field pid integer PID of the instance that created the swap file, or zero if not running
---@field mtime integer Last modification time in seconds
---@field inode? integer INODE number of the original file
---@field dirty integer 1 if file was was modified, 0 if not
---@field error? string Error message if any, otherwise nil

---@export NvimSwapInfo
