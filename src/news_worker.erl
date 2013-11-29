-module(news_worker).
-compile(export_all).
-record(news, {date = "", ticker = "", headline = "", url = ""}).

process_news(Ticker) ->
	inets:start(),
	URL = "http://feeds.finance.yahoo.com/rss/2.0/headline?s=" ++ Ticker ++ "&region=US&lang=en-US",
	try
		{ok, {_,_,M}} = httpc:request(URL, news),
		filter_and_process(M, Ticker)
	catch
		_:_ ->  exit({failed, Ticker})
	end.	

filter_and_process(File, Ticker) ->
	A = re:replace(File,"&apos;", "", [global, {return,list}]),
	B = re:replace(A,"&quot;", "", [global, {return,list}]),
	
	{XML, _} = xmerl_scan:string(B),
	News =  xmerl_xpath:string("//item", XML),
	lists:foreach(fun(H) -> extract_elements(H, Ticker) end, News).


extract_elements(Tuples, Ticker) ->
	{_, _, _, _, _, _, _, _, Items, _, _, _} = Tuples,
	make_rec(Items, Ticker).

make_rec(Items, Ticker) -> make_rec(Items, #news{ticker = Ticker}, 0).

make_rec([H|T], Rec, Count) ->
	NewRec = fill_record(H, Rec, Count),
	make_rec(T, NewRec, Count + 1);
make_rec([], _Rec, _) ->
	ok.

fill_record(H, Rec, N) ->
	[_,_,_,_,_,_,_,_,L|_] = tuple_to_list(H),
	case L of
		[] -> Rec;
		Element -> 
			[{_,_,_,_,Value,_}|_] = Element,
			if 
				N == 0 -> Rec#news{headline = Value};
				N == 1 -> Rec#news{url = Value};
				N == 2 -> Rec;
				N == 3 -> Rec;
				N == 4 -> Rec#news{date = Value}
			end
	end.
