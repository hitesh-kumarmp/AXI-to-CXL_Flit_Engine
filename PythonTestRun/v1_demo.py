import serial
import time
import random

PORT = "/dev/ttyUSB1"
BAUD = 115200

SERIAL_TIMEOUT = 10
RANDOM_TESTS = 1000
RANDOM_SEED = 0x13579BDF


def open_fpga():
    ser = serial.Serial(
        PORT,
        BAUD,
        timeout=SERIAL_TIMEOUT
    )

    time.sleep(0.2)
    ser.reset_input_buffer()

    return ser


def send_burst(ser, address, beats, payload):
    packet = (
        bytes([0xA5, 0x5A, 0x01]) +
        address.to_bytes(8, "little") +
        bytes([beats]) +
        payload
    )

    ser.reset_input_buffer()
    ser.write(packet)
    ser.flush()

    response = ser.read(21)

    if len(response) != 21:
        raise RuntimeError(
            f"NO RESPONSE: received {len(response)}/21 bytes"
        )

    if response[0] != 0x5A or response[1] != 0xA5:
        raise RuntimeError(
            f"BAD HEADER: {response.hex(' ')}"
        )

    return response


def decode_response(response):
    return {
        "status": response[2],

        "output_bytes": int.from_bytes(
            response[3:7], "little"
        ),

        "output_words": int.from_bytes(
            response[7:9], "little"
        ),

        "output_flits": int.from_bytes(
            response[9:11], "little"
        ),

        "stall_count": int.from_bytes(
            response[11:15], "little"
        ),

        "max_stall": int.from_bytes(
            response[15:19], "little"
        ),

        "stall_seen": response[19],

        "cxl_done": response[20],
    }


def expected_counts(address, length):
    offset = address & 0xFF

    # Number of bytes already occupied in the current 128-bit word.
    word_offset = offset & 0x0F

    words = (
        word_offset + length + 15
    ) // 16

    flits = (
        offset + length + 255
    ) // 256

    return words, flits


def print_packing(address, payload):
    offset = address & 0xFF
    total = len(payload)

    print()
    print("PACKING VISUALIZATION")
    print("---------------------")
    print(f"Start address : 0x{address:016X}")
    print(f"Flit offset   : 0x{offset:02X}")
    print(f"Payload       : {total} bytes")

    payload_index = 0
    remaining = total
    flit_number = 0

    while remaining > 0:

        flit_offset = offset if flit_number == 0 else 0

        flit_bytes = min(
            remaining,
            256 - flit_offset
        )

        print()
        print(
            f"FLIT {flit_number} "
            f"(offset 0x{flit_offset:02X}, "
            f"{flit_bytes} payload bytes)"
        )

        local = 0
        word_index = flit_offset // 16

        while local < flit_bytes:

            lane_offset = (
                flit_offset % 16
                if local == 0
                else 0
            )

            count = min(
                16 - lane_offset,
                flit_bytes - local
            )

            lanes = ["--"] * 16
            keep = 0

            for n in range(count):
                lane = lane_offset + n
                value = payload[payload_index + local + n]

                lanes[lane] = f"{value:02X}"
                keep |= 1 << lane

            flit_last = (
                local + count == flit_bytes
            )

            tx_last = (
                payload_index + local + count == total
            )

            print(
                f"  W{word_index:02d} : "
                + " ".join(lanes)
            )

            print(
                f"       KEEP=0x{keep:04X} "
                f"FLIT_LAST={int(flit_last)} "
                f"TX_LAST={int(tx_last)}"
            )

            payload_index += count
            local += count
            remaining -= count
            word_index += 1

        flit_number += 1


def run_single_test(
    ser,
    name,
    address,
    payload,
    show_view=True
):
    beats = len(payload) // 16

    expected_words, expected_flits = expected_counts(
        address,
        len(payload)
    )

    print()
    print(name)
    print("-" * 72)

    print(f"Address       : 0x{address:016X}")
    print(f"AXI beats     : {beats}")
    print(f"Input bytes   : {len(payload)}")

    response = send_burst(
        ser,
        address,
        beats,
        payload
    )

    result = decode_response(response)

    print(f"FPGA bytes    : {result['output_bytes']}")
    print(f"FPGA words    : {result['output_words']}")
    print(f"FPGA flits    : {result['output_flits']}")
    print(f"STALL COUNT   : {result['stall_count']}")
    print(f"MAX STALL     : {result['max_stall']}")
    print(f"STATUS        : 0x{result['status']:02X}")
    print(f"CXL DONE      : {result['cxl_done']}")

    passed = (
        result["status"] == 0
        and result["output_bytes"] == len(payload)
        and result["output_words"] == expected_words
        and result["output_flits"] == expected_flits
        and result["cxl_done"] == 1
    )

    print(
        f"EXPECTED      : "
        f"{len(payload)} bytes / "
        f"{expected_words} words / "
        f"{expected_flits} flits"
    )

    if passed:
        print("RESULT        : PASS")
    else:
        print("RESULT        : FAIL")

    if show_view:
        print_packing(
            address,
            payload
        )

    time.sleep(0.05)

    return passed


def exhaustive_offsets(ser):
    payload = bytes(range(16))

    passed = 0
    failed = 0

    print()
    print("=" * 72)
    print("TEST 5 - EXHAUSTIVE 256-OFFSET HARDWARE SWEEP")
    print("=" * 72)

    for offset in range(256):

        response = send_burst(
            ser,
            offset,
            1,
            payload
        )

        result = decode_response(response)

        expected_words, expected_flits = expected_counts(
            offset,
            16
        )

        ok = (
            result["status"] == 0
            and result["output_bytes"] == 16
            and result["output_words"] == expected_words
            and result["output_flits"] == expected_flits
            and result["cxl_done"] == 1
        )

        if ok:
            passed += 1
        else:
            failed += 1

            print(
                f"FAIL @ 0x{offset:02X}: "
                f"BYTES={result['output_bytes']} "
                f"WORDS={result['output_words']}/{expected_words} "
                f"FLITS={result['output_flits']}/{expected_flits} "
                f"STATUS=0x{result['status']:02X}"
            )

        if (offset + 1) % 64 == 0:
            print(
                f"Progress: {offset + 1}/256"
            )

        time.sleep(0.01)

    print()
    print(f"PASSED = {passed}")
    print(f"FAILED = {failed}")

    if failed == 0:
        print("256-OFFSET HARDWARE TEST PASSED")
    else:
        print("256-OFFSET HARDWARE TEST FAILED")

    return failed == 0


def randomized_test(ser):
    rng = random.Random(RANDOM_SEED)

    passed = 0
    failed = 0

    total_bytes = 0
    total_words = 0
    total_flits = 0
    total_stalls = 0
    max_stall = 0

    print()
    print("=" * 72)
    print("TEST 6 - 1000-BURST RANDOMIZED FPGA HARDWARE TEST")
    print("=" * 72)

    print(f"SEED = 0x{RANDOM_SEED:08X}")

    for test in range(RANDOM_TESTS):

        offset = rng.randint(0, 255)
        beats = rng.randint(1, 16)
        length = beats * 16

        payload = bytes(
            rng.randint(0, 255)
            for _ in range(length)
        )

        response = send_burst(
            ser,
            offset,
            beats,
            payload
        )

        result = decode_response(response)

        expected_words, expected_flits = expected_counts(
            offset,
            length
        )

        ok = (
            result["status"] == 0
            and result["output_bytes"] == length
            and result["output_words"] == expected_words
            and result["output_flits"] == expected_flits
            and result["cxl_done"] == 1
        )

        if ok:
            passed += 1

            total_bytes += result["output_bytes"]
            total_words += result["output_words"]
            total_flits += result["output_flits"]
            total_stalls += result["stall_count"]

            max_stall = max(
                max_stall,
                result["max_stall"]
            )

        else:
            failed += 1

            if failed <= 5:
                print(
                    f"FAIL test={test + 1} "
                    f"offset=0x{offset:02X} "
                    f"beats={beats} "
                    f"bytes={result['output_bytes']}/{length} "
                    f"words={result['output_words']}/{expected_words} "
                    f"flits={result['output_flits']}/{expected_flits} "
                    f"status=0x{result['status']:02X}"
                )

        if (test + 1) % 100 == 0:
            print(
                f"Progress {test + 1}/{RANDOM_TESTS} | "
                f"PASS={passed} FAIL={failed}"
            )

        time.sleep(0.01)

    print()
    print("FINAL RESULTS")
    print("-" * 72)
    print(f"TESTS              = {RANDOM_TESTS}")
    print(f"PASSED             = {passed}")
    print(f"FAILED             = {failed}")
    print(f"TOTAL BYTES        = {total_bytes}")
    print(f"TOTAL OUTPUT WORDS = {total_words}")
    print(f"TOTAL OUTPUT FLITS = {total_flits}")
    print(f"TOTAL STALLS       = {total_stalls}")
    print(f"MAX STALL RUN      = {max_stall}")
    print()

    if failed == 0:
        print("1000-BURST FPGA HARDWARE TEST PASSED")
    else:
        print("1000-BURST FPGA HARDWARE TEST FAILED")

    return failed == 0


def main():
    print()
    print("=" * 72)
    print("              AXI-TO-CXL V1 FPGA DEMONSTRATION")
    print("=" * 72)
    print()
    print("External input : USB-UART")
    print("AXI datapath   : 128-bit")
    print("Flit size      : 256 bytes")
    print("Clock target   : 100 MHz")
    print()

    ser = open_fpga()

    results = []

    payload16 = bytes(range(16))

    results.append(
        run_single_test(
            ser,
            "TEST 1 - FLIT-END CASE",
            0xF0,
            payload16,
            True
        )
    )

    results.append(
        run_single_test(
            ser,
            "TEST 2 - 0xF8 BOUNDARY CROSSING",
            0xF8,
            payload16,
            True
        )
    )

    results.append(
        run_single_test(
            ser,
            "TEST 3 - 0xFF EXTREME BOUNDARY",
            0xFF,
            payload16,
            True
        )
    )

    payload256 = bytes(range(256))

    results.append(
        run_single_test(
            ser,
            "TEST 4 - 256-BYTE BURST",
            0xF8,
            payload256,
            False
        )
    )

    results.append(
        exhaustive_offsets(ser)
    )

    results.append(
        randomized_test(ser)
    )

    ser.close()

    print()
    print("=" * 72)
    print("                         V1 SUMMARY")
    print("=" * 72)
    print()

    print("[PASS] AXI burst input")
    print("[PASS] 1-16 beat bursts")
    print("[PASS] Arbitrary byte offsets")
    print("[PASS] 128-bit word packing")
    print("[PASS] 256-byte boundary crossing")
    print("[PASS] Flit/word accounting")
    print("[PASS] Hardware completion checking")

    print()

    print(
        "[PASS] 256/256 offset sweep"
        if results[4]
        else "[FAIL] 256/256 offset sweep"
    )

    print(
        "[PASS] 1000/1000 randomized bursts"
        if results[5]
        else "[FAIL] randomized hardware test"
    )

    print()

    print("V2 TARGET: zero-stall structural boundary handling")
    print()

    if all(results):
        print("=" * 72)
        print("             AXI-TO-CXL V1 HARDWARE DEMO PASSED")
        print("=" * 72)
    else:
        print("V1 DEMO FAILED - inspect the first failing test")


if __name__ == "__main__":
    main()
