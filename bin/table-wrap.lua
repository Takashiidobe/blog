-- wrap each table in a scrollable div so wide tables don't overflow the page on mobile
function Table(el)
	return pandoc.Div(el, pandoc.Attr("", { "table-wrap" }))
end
