%%% @author  <Dungarov@DUNGAROV-PC>
%%% @copyright (C) 2013, 
%%% @doc
%%%
%%% @end
%%% Created : 7 Nov 2013 by  <Dungarov@DUNGAROV-PC>


-module(xmlp2).
-export([parse/1]).
-include_lib("xmerl/include/xmerl.hrl").

parse(File) ->
        {ok,Binary} = file:read_file(File),
        {Xml,_} = xmerl_scan:string(binary_to_list(Binary)),
        [[{Element,Value} || #xmlElement{name=Element,content=Value1} <- XmlElem, #xmlText{value=Value} <- Value1] || #xmlElement{content=XmlElem} <- xmerl_xpath:string("//item", Xml)].
