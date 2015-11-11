%% Index files are named [offset].index
%% Entries in the index are <<(Id-Offset):24/signed, Position:24/signed>>
%% Position is the offset in [offset].log to find the log Id
-module(vg_index).

-export([find_in_index/3]).

-spec find_in_index(Fd, BaseOffset, Id) -> integer() | not_found when
      Fd         :: file:fd(),
      BaseOffset :: integer(),
      Id         :: integer().
find_in_index(Fd, BaseOffset, Id) ->
    case file:read(Fd, 12) of
        {ok, Bytes} ->
            find_in_index_(Fd, Id, BaseOffset, Bytes);
        _ ->
            0
    end.

%% Optimize later. Could keep entire index in memory
%% and could (in memory or not) use a binary search
find_in_index_(_, _, _, <<>>) ->
    0;
find_in_index_(_, _, _, <<_:24/signed, Position:24/signed>>) ->
    Position;
find_in_index_(_, Id, BaseOffset, <<Offset:24/signed, Position:24/signed, _/binary>>)
  when Id =:= BaseOffset + Offset ->
    Position;
find_in_index_(_, Id, BaseOffset, <<_:24/signed, Position:24/signed, Offset:24/signed, _:24/signed, _/binary>>)
  when BaseOffset + Offset > Id ->
    Position;
find_in_index_(Fd, Id, BaseOffset, <<_:24/signed, _:24/signed, Rest/binary>>) ->
    case file:read(Fd, 6) of
        {ok, Bytes} ->
            find_in_index_(Fd, Id, BaseOffset, <<Rest/binary, Bytes/binary>>);
        _ ->
            find_in_index_(Fd, Id, BaseOffset, Rest)
    end.
