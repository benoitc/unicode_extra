#!/usr/bin/env escript
%% -*- erlang -*-
%%! +A0

-mode(compile).

-define(MOD, "unicodedata").


main(_) ->
  %%  Parse main table
  {ok, UD} = file:open("../uc_spec/UnicodeData.txt", [read, raw, {read_ahead, 1000000}]),
  Data = foldl(fun parse_unicode_data/2, [], UD),
  ok = file:close(UD),


  %% Make module
  OutputPath = filename:join(["..", "src", ?MOD++".erl"]),
  {ok, Out} = file:open(OutputPath, [write]),
  gen_file(Out, Data),
  ok = file:close(Out),
  ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-ifdef('OTP_RELEASE').
str_chomp(Str) -> string:chomp(Str).
str_lexemes(Str, Sep) -> string:lexemes(Str, Sep).
str_trim(Str, Dir) -> string:trim(Str, Dir).
-else.
strp_chomp(Str) -> string:strip(Str, right, $\n).
str_lexemes(Str, Sep) -> string:tokens(Str, Sep).
str_trim(Str, Dir) -> string:strip(Str, Dir).
-endif.


parse_unicode_data(Line0, Acc) ->
    Line = str_chomp(Line0),
    [CodePoint,_Name,Cat,Class,BiDi,_Decomp,
     _N1,_N2,_N3,_BDMirror,_Uni1,_Iso|_Case] = tokens(Line, ";"),
    [{hex_to_int(CodePoint), #{cat=>Cat, class=>to_class(Class), bidi=>BiDi}} | Acc].

to_class(String) ->
    list_to_integer(str_trim(String, both)).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gen_file(Fd, Data) ->
  gen_header(Fd),
  gen_static(Fd),
  gen_unicode_table(Fd, Data),
  ok.


gen_header(Fd) ->
  io:put_chars(Fd, "%%\n%% this file is generated do not modify\n"),
  io:put_chars(Fd, "%% see ../uc_spec/gen_unicode_mod.escript\n\n"),
  io:put_chars(Fd, "-module(" ++ ?MOD ++").\n"),
  io:put_chars(Fd, "-export([combining/1, category/1, bidirectional/1]).\n\n"),
  ok.

gen_static(Fd) ->
    io:put_chars(Fd, "combining(Codepoint) ->\n"
                 "  Map = unicode_table(Codepoint),\n"
                 "  case maps:find(class, Map) of\n"
                 "    {ok, C} -> C;\n"
                 "    error -> {error, Codepoint}\n"
                 "  end.\n\n"),
    io:put_chars(Fd, "category(Codepoint) ->\n"
                 "  Map = unicode_table(Codepoint),\n"
                 "  case maps:find(cat, Map) of\n"
                 "    {ok, Cat} -> Cat;\n"
                 "    error -> {error, Codepoint}\n"
                 "  end.\n\n"),
    io:put_chars(Fd, "bidirectional(Codepoint) ->\n"
                 "  Map = unicode_table(Codepoint),\n"
                 "  case maps:find(bidi, Map) of\n"
                 "    {ok, BiDi} -> BiDi;\n"
                 "    error -> {error, Codepoint}\n"
                 "  end.\n\n"),
    ok.



gen_unicode_table(Fd, Data) ->
    [io:format(Fd, "unicode_table(~w) -> ~p;~n", [CP, Map]) || {CP,Map} <- Data],
    io:format(Fd, "unicode_table(_) -> #{}.~n~n",[]),
    ok.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hex_to_int([]) -> [];
hex_to_int(HexStr) ->
  list_to_integer(str_trim(HexStr, both), 16).

foldl(Fun, Acc, Fd) ->
  Get = fun() -> file:read_line(Fd) end,
  foldl_1(Fun, Acc, Get).

foldl_1(_Fun, {done, Acc}, _Get) -> Acc;
foldl_1(Fun, Acc, Get) ->
  case Get() of
    eof -> Acc;
    {ok, "#" ++ _} -> %% Ignore comments
      foldl_1(Fun, Acc, Get);
    {ok, "\n"} -> %% Ignore empty lines
      foldl_1(Fun, Acc, Get);
    {ok, Line} ->
      foldl_1(Fun, Fun(Line, Acc), Get)
  end.



%% Differs from string:tokens, it returns empty string as token between two delimiters
tokens(S, [C]) ->
  tokens(lists:reverse(S), C, []).

tokens([Sep|S], Sep, Toks) ->
  tokens(S, Sep, [[]|Toks]);
tokens([C|S], Sep, Toks) ->
  tokens_2(S, Sep, Toks, [C]);
tokens([], _, Toks) ->
  Toks.

tokens_2([Sep|S], Sep, Toks, Tok) ->
  tokens(S, Sep, [Tok|Toks]);
tokens_2([C|S], Sep, Toks, Tok) ->
  tokens_2(S, Sep, Toks, [C|Tok]);
tokens_2([], _Sep, Toks, Tok) ->
  [Tok|Toks].
