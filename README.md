# Universally Unique Lexicographically Sortable Identifier (ULID)

## An [Odin](https://odin-lang.org/) implementation for ULID
## Please check the ULID [Specification](https://github.com/ulid/spec) to learn more

---

## Examples:

### Basic usage
```c
import "ulid"

ulid, err := ulid.generate_ulid()
if err != .None {
	// Handle Error
}
...
```

### If you need a monotonic generation(in case two ulids might be generated in the same millisecond)
```c
import "ulid"

ulid, err := ulid.generate_monotonic_ulid()
if err != .None {
	// Handle Error
}
...
```

### In case you need to decode an ulid string into its `u128be` value
```c
import "ulid"

using ulid
ulid, _ := generate_ulid()
value, err := decode(ulid)
if err != .None {
	// Handle Error
}
...
```
