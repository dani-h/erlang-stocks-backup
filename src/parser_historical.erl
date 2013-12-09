% Author : Dani Hodovic
% Historical parser V2. Incomplete as it needs to be compatible with the database. 
% For now it contains a test method for spawning
 % mini-processes and receiving messages from those printing it in in the shell.

-module(parser_historical).
-export([main/0]).
-compile(export_all).
-include("../include/defs.hrl").

%% Starts the inets, gets the list from nasdaqTickers
%% and calls to divide the list into multiple processes
main() ->
	inets:start(),
	All_Tickers = nasdaqTickers:get(),
	{A,B} = lists:split(100,All_Tickers),
	%%iterate_tickers(All_Tickers),
 	divide_tasks(A),
	inets:stop().

%% Divides all the tickers into 4 processes and 
%% spawn_links them
divide_tasks(List) ->
	{A, B} = lists:split(trunc(length(List)/2), List),
	{A1, A2} = lists:split(trunc(length(A)/2), A),
	{B1, B2} = lists:split(trunc(length(B)/2), B),
	spawn_link(?MODULE, iterate_tickers, [A1]),
 	spawn_link(?MODULE, iterate_tickers, [A2]),
 	spawn_link(?MODULE, iterate_tickers, [B1]),
 	spawn_link(?MODULE, iterate_tickers, [B2]).

%% Iterates the tickers supplised in a list
iterate_tickers([H|T]) ->
	processTicker(H),
	iterate_tickers(T);
iterate_tickers([]) ->
	ok.

%% Processes each ticker by getching the CSV for 
%% the historical data
processTicker(Ticker) ->
	{{Year, Month, Day}, _Time} = calendar:local_time(),
	SYear = integer_to_list(Year),
	SMonth = integer_to_list(Month),
	SDay = integer_to_list(Day),
	S = "http://ichart.yahoo.com/table.csv?s="++Ticker
		++"&a=5"++"&b=15"++"&c=2013"++"&d="++ SMonth ++ "&e="
		++ SDay ++ "&f="++ SYear
			++"&d=m&ignore=.csv",
	{CSV} = nasdaqTickers:getServer(S),
	case (string:chr(CSV, $!) > 0) of 
		false -> parse_csv({CSV}, Ticker);
		true -> error
	end.

%% Parses a single CSV file and calls iterate_records method to
%% iterate over it and create records
parse_csv(CSV, Ticker) ->
	[_|List] = re:split(tuple_to_list(CSV), "\n",
						[{return,list},{parts,infinity}]),
	All_Records = iterate_records(List, [], Ticker),
	
	genserv_sql:call_hist(whereis(sqlserv),lists:flatten(All_Records)).

% Iterates over records and calls iterate_records function 
% to make the actualy records for each line	
iterate_records([H|T], Acc, Ticker) ->
	String = string:tokens(H, ","),
	case String =/= [] of
	 true -> iterate_records(T, [make_rec(String, 0, #hist_stock{}, Ticker)|Acc], Ticker);
	 false -> Acc
	end;
iterate_records([], Acc, _Ticker) -> Acc.

%% Creates the records from a line of CSV 
make_rec([H|T], N, Rec, Ticker) -> 
	make_rec(T, N + 1, Rec#hist_stock{symbol = Ticker, date=((H -- [$-]) --[$-])}).
make_rec([H|T], N, Rec) when N == 1 -> 
	make_rec(T, N + 1, Rec#hist_stock{open=H});
make_rec([H|T], N, Rec) when N == 2 -> 
	make_rec(T, N + 1, Rec#hist_stock{high=H});
make_rec([H|T], N, Rec) when N == 3 -> 
	make_rec(T, N + 1, Rec#hist_stock{low=H});
make_rec([H|T], N, Rec) when N == 4 -> 
	make_rec(T, N + 1, Rec#hist_stock{close=H});
make_rec([H|T], N, Rec) when N == 5 -> 
	make_rec(T, N + 1, Rec#hist_stock{volume=H});
make_rec(_, _, Rec) ->
	Rec.
