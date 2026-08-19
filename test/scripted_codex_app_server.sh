#!/bin/sh

turn_number=0

while IFS= read -r line; do
  id=$(printf '%s' "$line" | /usr/bin/sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
  case "$line" in
    *'"method":"initialize"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"userAgent\":\"scripted-codex\",\"codexHome\":\"/tmp/codex\",\"platformFamily\":\"unix\",\"platformOs\":\"test\"}}"
      ;;
    *'"method":"skills/extraRoots/set"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      ;;
    *'"method":"skills/list"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"data\":[{\"skills\":[{\"name\":\"ribosome\",\"description\":\"Ribosome templates\",\"path\":\"/repo/skills/ribosome\",\"enabled\":true}]}]}}"
      ;;
    *'"method":"thread/start"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"thread\":{\"id\":\"thread-1\"}}}"
      ;;
    *'"method":"thread/resume"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"thread\":{\"id\":\"thread-1\"}}}"
      ;;
    *'"method":"turn/start"'*'fail'*)
      turn_number=$((turn_number + 1))
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"turn\":{\"id\":\"turn-$turn_number\"}}}"
      printf '%s\n' '{"jsonrpc":"2.0","method":"turn/completed","params":{"threadId":"thread-1","turn":{"id":"turn-2","status":"failed","error":{"message":"scripted failure"}}}}'
      ;;
    *'"method":"turn/start"'*)
      turn_number=$((turn_number + 1))
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"turn\":{\"id\":\"turn-$turn_number\"}}}"
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"method\":\"item/agentMessage/delta\",\"params\":{\"threadId\":\"thread-1\",\"turnId\":\"turn-$turn_number\",\"itemId\":\"item-$turn_number\",\"delta\":\"{\\\"kind\\\":\\\"submittable\\\",\\\"id\\\":\\\"form\\\",\\\"value\\\":[],\\\"button\\\":{\\\"kind\\\":\\\"button\\\",\\\"id\\\":\\\"save\\\",\\\"label\\\":\\\"Save\\\",\\\"action\\\":\\\"Submit\\\"}}\"}}"
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"method\":\"turn/completed\",\"params\":{\"threadId\":\"thread-1\",\"turn\":{\"id\":\"turn-$turn_number\",\"status\":\"completed\"}}}"
      ;;
    *'"method":"turn/interrupt"'*)
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"method\":\"turn/completed\",\"params\":{\"threadId\":\"thread-1\",\"turn\":{\"id\":\"turn-$turn_number\",\"status\":\"interrupted\"}}}"
      ;;
  esac
done
