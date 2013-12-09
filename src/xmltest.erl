%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created : 7 Nov 2013 by  <Dungarov@DUNGAROV-PC>


-module(xmltest).
 
-include_lib("xmerl/include/xmerl.hrl").
 
-export([main/0]).
 

%%xml_url() ->
%%  "http://articlefeeds.nasdaq.com/nasdaq/symbols?symbol=AAPL".
main() ->
Body = "
<RSS>
<Title>NewsTitle</Title>  %% XML body
<Text>Text</Text>
<Date>08-11-2013</Date>
</RSS>",

{Xml, _} = xmerl_scan:string(Body),  
    [val(xmerl_xpath:string("//Title", Xml)),
     val(xmerl_xpath:string("//Text", Xml)),
     val(xmerl_xpath:string("//Date", Xml))
    ].

val(X) ->
[#xmlElement{name = N, content = [#xmlText{value = V}|_]}] = X,
{N, V}.
