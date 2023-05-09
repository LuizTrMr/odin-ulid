// Source: https://github.com/ulid/spec
package ulid

import "core:fmt"
import "core:strings"
import "core:time"
import "core:math/rand"

REVERSE_TABLE := [256]byte{
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	  0,   1,   2,   3,   4,   5,   6,   7,   8,   9, 255, 255, 255, 255, 255, 255,
	255,  10,  11,  12,  13,  14,  15,  16,  17, 255,  18,  19, 255,  20,  21, 255,
	 22,  23,  24,  25,  26, 255,  27,  28,  29,  30,  31, 255, 255, 255, 255, 255,
	255,  10,  11,  12,  13,  14,  15,  16,  17, 255,  18,  19, 255,  20,  21, 255,
	 22,  23,  24,  25,  26, 255,  27,  28,  29,  30,  31, 255, 255, 255, 255, 255,
 	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
 	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
}

CROCKFORD    :: "0123456789ABCDEFGHJKMNPQRSTVWXYZ" // No I, L, O or U
MAX_TIME     :: (0b01 << 48) - 1
ENCODED_SIZE :: 26
RANDOM_BITS  :: 80
RANDOM_MASK  :: (0b01 << 80) - 1

Ulid_Error :: enum {
	None,
	Above_Max_Time,
	Extremely_Unlikely_Error,
	Unknown_Char, // Decode
	Invalid_Length, // Decode
	Overflow, // Decode
}

// 128bits ==> timestamp: 48bits, random: 80bits
Ulid :: distinct string 

@(private)
previous_random   : u128be = 0
@(private)
previous_timestamp: u128be = 0

generate_ulid :: proc() -> (Ulid, Ulid_Error) {
	timestamp := get_milliseconds()
	previous_timestamp = timestamp
	if timestamp > MAX_TIME do return "", .Above_Max_Time
	random := cast(u128be)rand.uint128() & RANDOM_MASK
	previous_random = random
	timestamp = timestamp << RANDOM_BITS
	ulid := encode( timestamp | random )
	return ulid, .None
}

generate_monotonic_ulid :: proc() -> (Ulid, Ulid_Error) {
	timestamp := get_milliseconds()
	if timestamp > MAX_TIME do return "", .Above_Max_Time
	random: u128be
	if previous_timestamp == timestamp {
		random = previous_random+1
	} else {
		random = cast(u128be)rand.uint128() & RANDOM_MASK
	}
	previous_timestamp = timestamp
	timestamp = timestamp << RANDOM_BITS

	previous_random = random
	ulid := encode( timestamp | random )
	return ulid, .None
}

decode :: proc(s: Ulid) -> (u128be, Ulid_Error) {
	ulid: u128be = 0
	size := len(s)
	if size != 26 do return 0, .Invalid_Length
	s := cast(string)s

	if s[0] > '7' do return 0, .Overflow
	for i in 0..<size {
		b := s[i]
		idx := cast(u128be)REVERSE_TABLE[b]
		if idx == 255 do return 0, .Unknown_Char
		ulid = (ulid << 5) | idx
	}
	return ulid, .None
}

@(private)
encode :: proc(ulid: u128be) -> Ulid {
	BASE: u128be : 32
	encoding := CROCKFORD
	sb := strings.builder_make()
	n := cast(u128be)ulid
	buf: [dynamic]byte
	defer delete(buf)
	for n != 0 {
		mod  := n % BASE
		char := encoding[mod]
		append(&buf, char)
		n /= BASE 
	}
	assert(len(buf) <= ENCODED_SIZE)

	fill := 26 - len(buf)
	for fill > 0 {
		strings.write_byte(&sb, '0')
		fill -= 1
	}

	for i := len(buf)-1; i >= 0; i -= 1 {
		strings.write_byte(&sb, buf[i])
	}
	assert(strings.builder_len(sb) == ENCODED_SIZE)

	return cast(Ulid)strings.to_string(sb)
}

@(private)
get_milliseconds :: proc() -> u128be {
	now := time.now() // Nanoseconds
	milliseconds := time.duration_milliseconds( time.Duration(now._nsec) ) // Milliseconds as f64
	return cast(u128be)milliseconds
}

run_tests :: proc() {
	test_decode()

	{ // Encode to Decode
		// Source: https://www.epochconverter.com/
		MILLISECONDS: u128be : 1683220628
		encoded_string := encode(MILLISECONDS)
		ulid, err := decode(encoded_string)
		assert( err == .None )
		assert( ulid == MILLISECONDS )
	}

	{ // Decode to Encode
		// Source: https://github.com/ulid/spec#universally-unique-lexicographically-sortable-identifier
		ULID_STRING :: "01ARZ3NDEKTSV4RRFFQ69G5FAV"
		ulid, err := decode(ULID_STRING)
		assert( err == .None )
		encoded_string := encode(ulid)
		assert( ULID_STRING == encoded_string )
	}
	
	{ // Monotonic Generation
		ulid1, _ := generate_monotonic_ulid()
		time.sleep(time.Microsecond)
		ulid2, _ := generate_monotonic_ulid()

		time.sleep(time.Millisecond)
		ulid3, _ := generate_monotonic_ulid()

		ulid1_n, _ := decode(ulid1)
		ulid2_n, _ := decode(ulid2)
		ulid3_n, _ := decode(ulid3)

		assert( ulid1_n+1 == ulid2_n ) // Generated in the same millisecond

		assert( ulid2_n+1 != ulid3_n ) // Generated in different milliseconds
	}

	{ // Transition from non Monotonic to Monotonic
		ulid1, _ := generate_ulid()
		ulid2, _ := generate_monotonic_ulid()

		ulid1_n, _ := decode(ulid1)
		ulid2_n, _ := decode(ulid2)

		assert( ulid1_n+1 == ulid2_n )
	}

	fmt.println("--- All tests passed ---")
}

test_decode :: proc() {
	res: u128be
	err: Ulid_Error

	// Overflow
	res, err = decode("7zzzzzzzzzzzzzzzzzzzzzzzzz")
	assert( err == .None )

	res, err = decode("80000000000000000000000000")
	assert( err == .Overflow )

	// Invalid Character
	res, err = decode("0000000000000000000000000u")
	assert( err == .Unknown_Char )

	res, err = decode("2o90x000000000000000000000")
	assert( err == .Unknown_Char )

	res, err = decode("0000000000000000000000i78b")
	assert( err == .Unknown_Char )

	res, err = decode("00000L00000000000000000000")
	assert( err == .Unknown_Char )

	// Invalid Length
	res, err = decode("a28173c") // Less than 26 characters
	assert( err == .Invalid_Length )

	res, err = decode("00000L0000000000000000000000") // More than 26 characters
	assert( err == .Invalid_Length )
}
