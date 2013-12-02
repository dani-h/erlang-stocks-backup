-module(news_main).
-compile(export_all).
-define(AMOUNT_OF_C_PROC, 50).

start() ->
	Tickers = startup(),
	% {A,_} = lists:split(1, Tickers),
	parse_news(Tickers).
%%         timer:apply_interval(216000000, ?MODULE, parse_news, [Tickers, Dates]).

startup() ->
	inets:start(),
	odbc:start(),
	register(),
	parse_nasdaq().

register() ->
	case whereis(?MODULE) of
		undefined -> register(?MODULE, self());
		_ -> already_defined
	end.

parse_nasdaq() ->
	io:format("Parsing Nasdaq..."),
	inets:start(httpc, [{profile, news}]),
	Tickers = lists:reverse(nasdaqTickers:get()),
	io:format("done~n~n"),
	Tickers.

parse_news(Tickers) ->
	parse_news(Tickers, ?AMOUNT_OF_C_PROC).

parse_news(Tickers, Segment_Size) when length(Tickers) > Segment_Size ->
	{A, B} = lists:split(Segment_Size, Tickers),
	spawn_workers(A),
	restart_inets(),
	parse_news(B, Segment_Size);
parse_news(Tickers, _Segment_Size) ->
	spawn_workers(Tickers),
	io:format("~n~nDone........restarting in: 6 hours~n~n").

spawn_workers(Tickers) ->
	spawn_workers(Tickers, 0).

spawn_workers([One_Ticker|Rest], Children) ->
	spawn_link(rss, process_ticker, [One_Ticker]),
	spawn_workers(Rest, Children + 1);
spawn_workers([], Children) ->
	loop_receive(Children).

loop_receive(Children) ->
	process_flag(trap_exit, true),
	loop_receive(Children, 0).
loop_receive(Children, Normal_Exits) ->
	case Children == Normal_Exits of 
		true ->
			{_, {H, Min, Sec}} = calendar:local_time(),
			io:format("**Time: ~p:~p:~p, Finished segment of size: ~p**~n", [H, Min, Sec, Children]);
		false ->
			receive
				{'EXIT', Pid, {failed, Ticker}} ->
					io:format("RESTARTING PROCESS: ~p~n", [Pid]),
					spawn_link(rss, process_ticker, [Ticker]),
					loop_receive(Children, Normal_Exits);
				{'EXIT', _Pid, normal} ->
					loop_receive(Children, Normal_Exits + 1);
				Catch_All -> 
					io:format("Catch_All: ~p", [Catch_All]),
					loop_receive(Children, Normal_Exits + 1)
			end
	end.

restart_inets() ->
	inets:stop(httpc, news),
	inets:start(httpc, [{profile, news}]).