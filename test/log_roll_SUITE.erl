-module(log_roll_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile(export_all).

all() ->
    [message_set_larger_than_max_segment].

init_per_testcase(_, Config) ->
    PrivDir = ?config(priv_dir, Config),
    application:load(vonnegut),
    application:set_env(vonnegut, log_dirs, [filename:join(PrivDir, "data")]),
    application:set_env(vonnegut, segment_bytes, 86),
    application:set_env(vonnegut, index_max_bytes, 18),
    application:set_env(vonnegut, index_interval_bytes, 24),
    application:ensure_all_started(vonnegut),
    crypto:start(),
    Config.

end_per_testcase(_, Config) ->
    Config.

message_set_larger_than_max_segment(_Config) ->
    Topic = vg_test_utils:create_random_name(<<"test_topic">>),
    Partition = 0,
    TopicPartitionDir = vg_utils:topic_dir(Topic, Partition),
    vg:create_topic(Topic),
    ?assert(filelib:is_dir(TopicPartitionDir)),

    vg:write(Topic, [crypto:strong_rand_bytes(60), crypto:strong_rand_bytes(60),
                     crypto:strong_rand_bytes(6), crypto:strong_rand_bytes(6),
                     crypto:strong_rand_bytes(60)]),

    %% Total size of a 60 byte message when written to log becomes 86 bytes
    %% Since index interval is 24 and 86 > 24, 1 index entry of 6 bytes should exist for each as well
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000000.index"])), 6),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000000.log"])), 86),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000001.index"])), 6),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000001.log"])), 86),

    %% Next 2 messages create a log with 2 messages of 6 bytes each (with headers they are 32 bytes)
    %% with ids 2 and 3. The third message (id 4) then goes in a new index and log
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000002.index"])), 12),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000002.log"])), 64),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000004.index"])), 6),
    ?assertEqual(filelib:file_size(filename:join([TopicPartitionDir, "00000000000000000004.log"])), 86).
