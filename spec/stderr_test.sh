#! /bin/sh

echo "foo" >&1
echo "bar" >&2
echo "baz" >&1

exit $1
