-module(hist_worker).

-include("../include/defs.hrl").
-compile(export_all).

%% Processes each ticker by getching the CSV for 
%% the historical data
process_ticker(Ticker, Dates) ->
	{_,{Hour,Min,Sec}} = erlang:localtime(),
	{{Old_Year, Old_Month, Old_Day}, 
	 {Recent_Year, Recent_Month, Recent_Day}} = Dates,
	URL = "http://ichart.yahoo.com/table.csv?s="++Ticker
		++"&a=" ++ Old_Month ++"&b="++ Old_Day ++ "&c=" ++ Old_Year
		++"&d="++ Recent_Month ++ "&e=" ++ Recent_Day ++ "&f="++ Recent_Year
			++"&d=m&ignore=.csv",
	try
		{ok, {_,_,CSV}} = httpc:request(URL, foo),
		case (string:chr(CSV, $!) > 0) of 
			false ->	
				io:format("Pid: ~p, Processing Ticker:~p at ~p:~p:~p~n", [self(), Ticker, Hour, Min, Sec]),
				parse_csv({CSV}, Ticker);
			true -> 	ok
		end
	catch
		_:_ -> io:format("~nEXITING~n"), exit({Ticker, Dates})
	end.
	

%% Parses a single CSV file and calls iterate_records method to
%% iterate over it and create records
parse_csv(CSV, Ticker) ->
	[_|List] = re:split(tuple_to_list(CSV), "\n",
						[{return,list},{parts,infinity}]),
	{ok, Pid} = odbc:connect(?ConnectStr,[{timeout, 500000}]),
	iterate_records(List, [], Ticker,  Pid),
	odbc:disconnect(Pid).
	% parser ! {self(), done}.

% Iterates over records and calls iterate_records function 
% to make the actualy records for each line	
iterate_records([H|T], Acc, Ticker, Pid) ->
	String = string:tokens(H, ","),
	case String =/= [] of
	 true -> iterate_records(T, [make_records(H, Ticker, Pid)|Acc], Ticker, Pid);
	 false -> Acc
	end;
iterate_records([], Acc, _Ticker, _Pid) -> Acc.

%% Makes the records
make_records(Line, Ticker, Pid) ->
	[Date, Open, High, Low, Close, Volume, _] = string:tokens(Line, ","),
	H = #hist_stock{symbol = Ticker, date = Date, open = Open, high = High,
				low = Low, close = Close, volume = Volume},
	Query = gen_entry(historical, H) ++ ";",
	_Result = odbc:sql_query(Pid, Query).
	
gen_entry(historical, R) -> "EXEC s_addHistorical @Symbol='"++R#hist_stock.symbol++"',@Date='"++R#hist_stock.date++"',@Open="++R#hist_stock.open++",@Close="++R#hist_stock.close++",@MaxPrice="++R#hist_stock.high++",@MinPrice="++R#hist_stock.low++",@Volume="++R#hist_stock.volume.

				