-module(hist_main).
-include("../include/defs.hrl").
-compile(export_all).

test() ->
	T = startup(),
	parse_yahoo(T, convert_dates(default)).

start(Old, Recent) ->
	main(Old, Recent).
	
start(default) ->
	main(default).
	
main(default) ->
	Tickers = startup(),
	Dates = convert_dates(default),
	parse_yahoo(Tickers, Dates),
	timer:apply_interval(216000000, ?MODULE, parse_yahoo, [Tickers, Dates]).

main(Old, Recent) ->
	Tickers = startup(),
	Dates = convert_dates(Old, Recent),
	parse_yahoo(Tickers, Dates),
	RecentDates = convert_dates(default),
	timer:apply_interval(216000000, ?MODULE, parse_yahoo, [Tickers, RecentDates]).
	
startup() ->
	inets:start(),
	odbc:start(),
	register(),
	spawn_link(db, start, []),
	parse_nasdaq().

register() ->
	case whereis(?MODULE) of
		undefined -> register(?MODULE, self());
		_ -> already_defined
	end.
	
parse_nasdaq() ->
	io:format("Parsing Nasdaq..."),
	inets:start(httpc, [{profile, foo}]),
	Tickers = lists:reverse(nasdaqTickers:get()),
	io:format("done~n~n"),
	Tickers.

parse_yahoo(Tickers, Dates) ->
	parse_yahoo(Tickers, Dates, 500).

parse_yahoo(Tickers, Dates, Segment_Size) when length(Tickers) > Segment_Size ->
	{A, B} = lists:split(Segment_Size, Tickers),
	spawn_workers(A, Dates),
	restart_inets(),
	parse_yahoo(B, Dates, Segment_Size);
parse_yahoo(Tickers, Dates, _Segment_Size) ->
	spawn_workers(Tickers, Dates),
	io:format("~n~nDone........restarting in: 6 hours~n~n").

spawn_workers(Tickers, Dates) ->
	spawn_workers(Tickers, Dates, 0).

spawn_workers([One_Ticker|Rest], Dates, Children) ->
	spawn_link(hist_worker, process_ticker, [One_Ticker, Dates]),
	spawn_workers(Rest, Dates, Children + 1);
spawn_workers([], _Dates, Children) ->
	loop_receive(Children).

loop_receive(Children) ->
	process_flag(trap_exit, true),
	loop_receive(Children, 0).
loop_receive(Children, Normal_Exits) ->
	case Children == Normal_Exits of 
		true ->
			io:format("**Finished segment of size: ~p**~n", [Children]);
		false ->
			receive
				{'EXIT', _Pid, {A, B}} ->
					P = spawn_link(worker, process_ticker, [A, B]),
					io:format("~n~nRESTARTING PROCESS: ~p~n~n", [P]),
					loop_receive(Children, Normal_Exits);
				{'EXIT', _Pid, normal} ->
					loop_receive(Children, Normal_Exits + 1);
				Catch_All -> 
					io:format("Catch_All: ~p", [Catch_All]),
					loop_receive(Children, Normal_Exits)
			end
	end.

restart_inets() ->
	inets:stop(httpc, foo),
	inets:start(httpc, [{profile, foo}]).
	
convert_dates(default) ->
	{{Year, Month, Day}, {_,_,_}} = calendar:local_time(),
	Recent_Return = date_helper(integer_to_list(Year) 
		++ integer_to_list(Month) ++ integer_to_list(Day)),
	case Day < 3 of
		false ->
			Old_Return = date_helper(integer_to_list(Year) ++
				integer_to_list(Month) ++ integer_to_list(Day - 3));
		true ->
			Old_Return = date_helper(integer_to_list(Year)++
				integer_to_list(Month - 1) ++ integer_to_list(28))
	end,
	case Old_Return < Recent_Return of
		true ->
			{Old_Return, Recent_Return};
		false ->
			throw("Invalid dates, the second argument must be the recent date")
	end.

convert_dates(Old, Recent) ->
	Old_Return = date_helper(Old),
	Recent_Return = date_helper(Recent),
	case Old_Return < Recent_Return of
		true -> 
			{Old_Return, Recent_Return};
		false ->
			throw("Invalid dates, the second argument must be the recent date")
	end.
	
date_helper(Date) ->
	{Year_String, MonthDay_String} = lists:split(4, Date),
	{Month_String, Day_String} = lists:split(2, MonthDay_String),
	Year = list_to_integer(Year_String),
	Month = list_to_integer(Month_String),
	Day = list_to_integer(Day_String),
	case calendar:valid_date(Year, Month, Day) of
		false -> throw("Invalid dates");
		true -> 
			Return_Year = integer_to_list(Year),
			Return_Day = integer_to_list(Day),
			if 
				Month == 1 -> Return_Month = "12";
				true -> Return_Month = integer_to_list(Month - 1)
			end,
			{Return_Year, Return_Month, Return_Day}
	end.
