#!/usr/bin/env python3

import subprocess
import sys

CASES = r'''
# ===== String commands (GET/SET/DEL) =====
$ ./client get unknown
(nil)
$ ./client set k1 v1
(nil)
$ ./client get k1
(str) v1
$ ./client set k1 v2
(nil)
$ ./client get k1
(str) v2
$ ./client del k1
(int) 1
$ ./client get k1
(nil)
$ ./client del k1
(int) 0

# ===== KEYS command =====
$ ./client keys
(arr) len=0
(arr) end
$ ./client set a 1
(nil)
$ ./client set b 2
(nil)
$ ./client set c 3
(nil)
'''

import shlex

def run_single(cmd):
    try:
        out = subprocess.check_output(
            shlex.split(cmd),
            stderr=subprocess.STDOUT,
            timeout=5
        ).decode('utf-8')
        return out, None
    except subprocess.CalledProcessError as e:
        return e.output.decode('utf-8'), None
    except subprocess.TimeoutExpired:
        return None, f"TIMEOUT: {cmd}"

def run_tests():
    cmds = []
    outputs = []
    lines = CASES.splitlines()
    for x in lines:
        x = x.strip()
        if not x or x.startswith('#'):
            continue
        if x.startswith('$ '):
            cmds.append(x[2:])
            outputs.append('')
        else:
            outputs[-1] = outputs[-1] + x + '\n'

    assert len(cmds) == len(outputs), f"cmds={len(cmds)} outputs={len(outputs)}"

    passed = 0
    failed = 0
    for i, (cmd, expect) in enumerate(zip(cmds, outputs)):
        out, timeout_err = run_single(cmd)
        if timeout_err:
            print(timeout_err)
            failed += 1
            continue

        if out == expect:
            passed += 1
            print(f"PASS [{i+1}/{len(cmds)}]: {cmd}")
        else:
            failed += 1
            print(f"FAIL [{i+1}/{len(cmds)}]: {cmd}")
            print(f"  EXPECT:\n{repr(expect)}")
            print(f"  GOT:\n{repr(out)}")
            sys.exit(1)

    # Additional tests that require flexible checking

    # Test KEYS with 3 keys (order is non-deterministic)
    out, _ = run_single("./client keys")
    lines_out = out.strip().split('\n')
    assert len(lines_out) >= 2, f"Expected at least 2 lines, got: {out}"
    assert lines_out[0] == "(arr) len=3", f"Expected len=3, got: {lines_out[0]}"
    assert lines_out[-1] == "(arr) end", f"Expected arr end, got: {lines_out[-1]}"
    keys = sorted([l[6:] for l in lines_out[1:-1] if l.startswith("(str) ")])
    expected_keys = sorted(["a", "b", "c"])
    assert keys == expected_keys, f"Keys mismatch: {keys} vs {expected_keys}"
    passed += 1
    print(f"PASS [bonus]: keys (sorted check)")

    # Test ZSET
    zset_cases = [
        ("./client zscore zset n1", "(nil)\n"),
        ("./client zquery zset 1 '' 0 10", "(arr) len=0\n(arr) end\n"),
        ("./client zadd zset 1 n1", "(int) 1\n"),
        ("./client zadd zset 2 n2", "(int) 1\n"),
        ("./client zadd zset 1.1 n1", "(int) 0\n"),
        ("./client zscore zset n1", "(dbl) 1.1\n"),
        ("./client zscore zset n2", "(dbl) 2\n"),
        ("./client zquery zset 1 '' 0 10", "(arr) len=4\n(str) n1\n(dbl) 1.1\n(str) n2\n(dbl) 2\n(arr) end\n"),
        ("./client zquery zset 1.1 '' 1 10", "(arr) len=2\n(str) n2\n(dbl) 2\n(arr) end\n"),
        ("./client zquery zset 1.1 '' 2 10", "(arr) len=0\n(arr) end\n"),
        ("./client zrem zset nosuch", "(int) 0\n"),
        ("./client zrem zset n1", "(int) 1\n"),
        ("./client zquery zset 1 '' 0 10", "(arr) len=2\n(str) n2\n(dbl) 2\n(arr) end\n"),
    ]
    for cmd, expect in zset_cases:
        out, _ = run_single(cmd)
        if out == expect:
            passed += 1
            print(f"PASS [bonus]: {cmd}")
        else:
            failed += 1
            print(f"FAIL [bonus]: {cmd}")
            print(f"  EXPECT:\n{repr(expect)}")
            print(f"  GOT:\n{repr(out)}")
            sys.exit(1)

    # Test TTL
    ttl_cases = [
        ("./client pttl noexist", "(int) -2\n"),
        ("./client set tk tv", "(nil)\n"),
        ("./client pttl tk", "(int) -1\n"),
        ("./client pexpire tk 5000", "(int) 1\n"),
        ("./client pexpire noexist 5000", "(int) 0\n"),
        ("./client del tk", "(int) 1\n"),
    ]
    for cmd, expect in ttl_cases:
        out, _ = run_single(cmd)
        if out == expect:
            passed += 1
            print(f"PASS [bonus]: {cmd}")
        else:
            failed += 1
            print(f"FAIL [bonus]: {cmd}")
            print(f"  EXPECT:\n{repr(expect)}")
            print(f"  GOT:\n{repr(out)}")
            sys.exit(1)

    # Cleanup
    for cleanup_cmd in ["./client del a", "./client del b", "./client del c", "./client del zset"]:
        run_single(cleanup_cmd)

    print(f"\n=== Results: {passed} passed, {failed} failed ===")
    return failed == 0

if __name__ == '__main__':
    if not run_tests():
        sys.exit(1)
