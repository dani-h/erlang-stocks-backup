-module(news_worker).
-compile(export_all).
-include("../include/defs.hrl").

process_news(Ticker) ->
	inets:start(),
	URL = "http://feeds.finance.yahoo.com/rss/2.0/headline?s=" ++ Ticker ++ "&region=US&lang=en-US",
	% io:format("~p~n", [URL]).
	% try
		{ok, {_,_,Unfiltered}} = httpc:request(URL),
		% io:format("~ts~n", [Unfiltered]).
		% fix(Unfiltered).
		% io:format("~ts~n", [fix(Unfiltered)]).
		% Z = unicode:characters_to_list(Unfiltered, latin1),
		% fix_unicode(Unfiltered).
		% Filtered = filter(Unfiltered),
		process_xml(fix(Unfiltered), Ticker).
	% catch
		% _:_ ->  exit({failed, Ticker})
	% end.	
	
	% apei
	% "http://finance.yahoo.com/news/american-public-university-system-selected-161700818.html


fix(Unfiltered) ->
	Filtered = delete(Unfiltered),
	% Binary = unicode:characters_to_binary(Filtered, unicode, latin1),
	% Dani = binary_to_list(Binary),
	A = re:replace(Filtered, "&quot;", "", [global, {return, list}]),
	B = re:replace(A, "&apos;", "", [global, {return, list}]),
	B.
	
delete(List) -> delete(List, []).

delete([H|T], Acc) when H > 127 ->
	% io:format("~p~n", [H]),
	delete(T, Acc);
delete([H|T], Acc) ->
	delete(T, Acc ++ [H]);
delete([], Acc) -> 
	Acc.
	
	
% fix_unicode(XmlString) ->
	% B = re:split(A, "
	% Binary = unicode:characters_to_binary(XmlString, unicode, latin1),
	% N = binary_to_list(Binary),
	% A = re:replace(N, "&quot;", "", [global, {return, list}]),
	% B = re:replace(A, "&apos;", "", [global, {return, list}]),
	% C = re:replace(B, "&rsquo;", "", [global, {return, list}]),%â
	% io:format("~s~n", [re:split(B, "q", [{return, binary}])]).
	% io:format("~ts~n", [N]).
	
process_xml(File, Ticker) ->
	{XML, _} = xmerl_scan:string(File),
	News =  xmerl_xpath:string("//item", XML),
	lists:foreach(fun(H) -> extract_elements(H, Ticker) end, News).
	
extract_elements(Tuples, Ticker) ->
	{_, _, _, _, _, _, _, _, Items, _, _, _} = Tuples,
	make_rec(Items, Ticker).

make_rec(Items, Ticker) -> 
	{ok, Pid} = odbc:connect(?ConnectStr,[{timeout, 500000}]),
	make_rec(Items, #news{ticker = Ticker}, 0, Pid),
	odbc:disconnect(Pid).
	

make_rec([H|T], Rec, Count, Pid) ->
	NewRec = fill_record(H, Rec, Count),
	make_rec(T, NewRec, Count + 1, Pid);
make_rec([], Rec, _, Pid) ->
	Query = gen_entry(news, Rec) ++ ";",
	% case length(Query) > 400 of 
		% true -> 
			% io:format("~p~n", [Rec]);
			% io:format("~p~n", [Query]);
		% false -> ok
	% end,
    _Result = odbc:sql_query(Pid, Query),
	% io:format("~p~n", [Result]),
	ok.

fill_record(H, Rec, N) ->
	[_,_,_,_,_,_,_,_,L|_] = tuple_to_list(H),
	case L of
		[] -> Rec;
		Element -> 
			[{_,_,_,_,Value,_}|_] = Element,
			if 
				N == 0 -> Rec#news{headline = Value};
				N == 1 -> Rec#news{url = format_url(Value)};
				N == 2 -> Rec;
				N == 3 -> Rec;
				N == 4 -> Rec#news{date = format_date(Value)}
			end
	end.
	
format_url(Var) ->
	case string:tokens(Var, "*") of
		[URL] -> URL;
		[_, URL] ->	URL;
		[_, _, URL] -> URL
	end.
	
format_date(Var) ->
	{{Y, M, D}, _} = ec_date:parse(Var),
	Date = integer_to_list(Y) ++ "-"
			++ integer_to_list(M) ++ "-"
			++ integer_to_list(D),
	Date.

gen_entry(news,R) -> "EXEC s_addNews @Date='"++R#news.date++"',@Symbol='"++R#news.ticker++"',@Headline='"++R#news.headline++"',@Hyperlink='"++R#news.url++"'".
