// read json data
d3.json("sample_json.json").then(loadData);

//setting dimensions and margins for graph
//var width = 1000;
//var height = 1000;
var margin = {top: 20, right: 90, bottom: 30, left: 90}
var width = 1500 - margin.left - margin.right //change width because leaf nodes were going out
var height = 1200 - margin.top - margin.bottom; //1200 height for about 40 leaf nodes

// appending svg object to the body div "container"
var svg = d3.select("#container")
    .append("svg")
        .attr("width", width + margin.right + margin.left)
        .attr("height", height + margin.top + margin.bottom)
    .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

var i = 0
var duration = 750
var root;

// Auto-scroll
var scrollCount = 1;
while (scrollCount < 2) {
    autoscroll();
    scrollCount++ ;
}

function loadData(data) {

    console.log(data)
    // assigning initial value to level labels for deactivating transition
    var label_level_1, label_level_2, label_level_3, label_level_4,label_level_5;
    label_level_1 = label_level_2 = label_level_3 = label_level_4 = label_level_5 = 1;

    // Create the cluster layout:
    var tree = d3.tree()
        .size([height,width]) 
        .separation((a,b) => {return a.parent == b.parent ? 1 : 1;}); // for separating nodes nicely
    
    // Give the data to the tree layout:
    root = d3.hierarchy(data, function(d) {
        return d.children;
    });
    root.x0 = height / 2;
    root.y0 = 0;

    // Collapse after the second level
    root.children.forEach(collapse); // by default collapse level
    //tree.nodes(root).forEach(function(n) { toggle(n); });
    collapse(root); // to have it at the first level by default
    update(root);

    // Collapse the node and all it's children
    function collapse(d) {
        if (d.children) {
            d._children = d.children
            d._children.forEach(collapse)
            d.children = null
        }
    
    }

    function update(source) {
        // x and y position for nodes;
        var treeData = tree(root);

        // compute the new tree layout
        var nodes = treeData.descendants()
        var links = treeData.descendants().slice(1);

        //Normalizing for fixed depth
        nodes.forEach(d => {d.y = d.depth * 235}); //d.y dictates how much tree unfolds in x axis distance because it is a horizontal tree, if it was vertical d.y would affect y axis

        // Adding labels for each level
        // using underscore.js library
        var depthOrder = _.uniq(_.pluck(nodes, "depth")).sort();
        svg.selectAll("g.levels-svg").remove();
        var levelSVG = svg.append("g").attr("class", "levels-svg");
        var levels =  levelSVG.selectAll("g.level");
        levels.data(depthOrder)
            .enter().append("g")
            .attr("class", "level")
            .attr("transform", function(d) { return "translate(" + d*235 + "," + 10 + ")"; })
            .append("text")
            .text(function(d){
                if (d === 0){
                    if (label_level_1 === 1){
                        d3.select(this)
                        .attr("fill-opacity", 0)
                        .transition().duration(1500)
                        .attr("fill-opacity", 1)
                    }
                    label_level_1++;
                    return data.children[0].colname;
                }
                if (d === 1){
                    if (label_level_2 === 1){
                        d3.select(this)
                        .attr("fill-opacity", 0)
                        .transition().duration(1500)
                        .attr("fill-opacity", 1)
                    }
                    label_level_2++;
                    return data.children[0].children[0].colname;
                }
                else if (d === 2){
                    if (label_level_3 === 1){
                        d3.select(this)
                        .attr("fill-opacity", 0)
                        .transition().duration(1500)
                        .attr("fill-opacity", 1)
                    }
                    label_level_3++;
                    return data.children[0].children[0].children[0].colname;
                }
                else if (d === 3){
                    if (label_level_4 === 1){
                        d3.select(this)
                        .attr("fill-opacity", 0)
                        .transition().duration(1500)
                        .attr("fill-opacity", 1)
                    }
                    label_level_4++;
                    return data.children[0].children[0].children[0].children[0].colname;
                }
                else if (d === 4){
                    if (label_level_5 === 1){
                        d3.select(this)
                        .attr("fill-opacity", 0)
                        .transition().duration(1500)
                        .attr("fill-opacity", 1)
                    }
                    label_level_5++;
                    return data.children[0].children[0].children[0].children[0].children[0].colname;
                }
            })
            .attr("x", -10)
            .attr("font-family","arial")
            .style("font-weight", "bold")
            .style("fill", "#777777");
              

        // NODES *********************************************
        // updating nodes
        var node = svg.selectAll('g.node')
            .data(nodes, d => {return d.id || (d.id = ++i); }) //assigning them a unique id

        // Enter any new nodes at the parent's previous position
        var nodeEnter = node.enter().append('g')
            .attr('class', 'node')
            .attr('transform', d => { return "translate(" + source.y0 + "," + source.x0 + ")"})
            .on('click', click); //defined this function below
        
        // add circle for the nodes
        nodeEnter.append('circle')
            .attr('class', 'node')
            .attr('r', 0) // before merging
            .style("fill", "#E55E69" )
            //.style("fill", d => {return d._children ? "blue" : "#fff";}) //before merging

        // ADD LABELS FOR THE NODES
        nodeEnter.append('text')
            .attr("dy", "0.35em")
            .attr("x", function(d) {
                return d.children || d._children ? -13 : 13;})
            //.attr("y", -4) 
            .attr("text-anchor", function(d) {
                return d.children || d._children ? "end" : "start";
                
            })
            .text(function(d) { return d.data.name; })
            .call(wrap, 250)  // wrap text labels to 2 lines
            .attr("font-size", "11")
            .style('fill-opacity', 1e-6)
            .style("font-family", "arial")
            .style("fill", "#777777")
            .style("font-weight", "bold")
            .style("text-shadow", "-1px -1px 3px white, -1px 1px 3px white, 1px -1px 3px white, 1px 1px 3px white")
            .style("word-break", "normal");

        // UPDATE
        var nodeUpdate = nodeEnter.merge(node); //merge all the elements you "entered"


        // Transition to the proper position for the node
        nodeUpdate.transition()
            .duration(duration)
            .attr("transform", d => {return "translate(" + d.y + "," + d.x + ")";})
            

        // Update node attributes and style
        nodeUpdate.select('circle') // before it said "circle.node"
            .style("fill", "#E55E69")
            //.style("fill", d => {return d._children ? "red" : "blue";})
            .attr('cursor', d => { return d.children || d._children ? 'pointer' : 'default';}) 
            .on("mouseover", function(d) {
                if (d._children) {
                    d3.select(event.currentTarget).style("fill", "#35BFBA");
                    d3.select(event.currentTarget).attr("r", "12"); 
                }
                })
            .on("mouseout", d => {d3.select(event.currentTarget)
                .style("fill", "#E55E69")
                .attr("r", "6.5");
            })
            .transition()
            .duration(duration)
            .attr('r', "6.5");

        // Update label/text attributes (transition)
        nodeUpdate.select('text')
            .transition()
            .duration(duration)
            .style('fill-opacity', 1);
            
        // Remove any exiting nodes
        var nodeExit = node.exit().transition()
            .duration(duration)
            .attr("transform", function(d) {
                return "translate(" + source.y + "," + source.x + ")";
            })
            .remove();

        // On exit reduce the node circles size to 0
        nodeExit.select('circle')
            .attr('r', 1e-6); 

        // On exit reduce the opacity of text labels
        nodeExit.select('text')
            .style('fill-opacity', 1e-6); 


        //LINKS***************************************

        // Update the links...
        var link = svg.selectAll('path.link')
            .data(links, function(d) { return d.id; });

        // Enter any new links at the parent's previous position.
        var linkEnter = link.enter().insert('path', "g")
            .attr("class", "link")
            .attr('d', function(d){
                var o = {x: source.x0, y: source.y0}
                return diagonal(o, o)
            });

        // UPDATE
        var linkUpdate = linkEnter.merge(link);

        // Transition back to the parent element position
        linkUpdate.transition()
            .duration(duration)
            .attr('d', function(d){ return diagonal(d, d.parent) })
            .attr("fill", "none")   // without this its gonna fill all black
            .attr("stroke", "#ccc"); // for the black line connecting nodes

        // Remove any exiting links
        var linkExit = link.exit().transition()
            .duration(duration)
            .attr('d', function(d) {
                var o = {x: source.x, y: source.y}
                return diagonal(o, o)
            })
            .remove();

        // Store the old positions for transition.
        nodes.forEach(function(d){
            d.x0 = d.x;
            d.y0 = d.y;
        });

        // Creates a curved (diagonal) path from parent to the child nodes
        function diagonal(s, d) {
/*
            path = `M ${s.y} ${s.x}
                    C ${(s.y + d.y) / 2} ${s.x},
                    ${(s.y + d.y) / 2} ${d.x},
                    ${d.y} ${d.x}`
*/                  path = "M" + s.y + "," + s.x
                    + "C" + (d.y + 20) + "," + s.x
                    + " " + (d.y + 10) + "," + d.x
                    + " " + d.y + "," + d.x;
            return path
        }

        // Toggle children on click.
        function click(d) {
            if (d.children) {
                d._children = d.children;
                d.children = null;
                //to make level label transitions work after collapsing
                if (depthOrder.length === 1){
                    label_level_2--;
                }
                else if (depthOrder.length === 2){
                    label_level_3--;
                }
                else if(depthOrder.length === 3){
                    label_level_4--;
                }
                else if(depthOrder.length === 4){
                    label_level_5--;
                }
            } else {
                d.children = d._children;
                d._children = null;
            }
            update(d);
            }
        
        function wrap(text, width) {
            text.each(function() {
                var text = d3.select(this),
                words = text.text().split(/\s+/).reverse(),
                word,
                line = [],
                lineNumber = 0,
                lineHeight = 1, // ems
                x = text.attr("x"),
                y = text.attr("y"),
                dy = parseFloat(text.attr("dy")),
                tspan = text.text(null).append("tspan").attr("x", x).attr("y", y).attr("dy", dy + "em"); // removed dy + em for making equal line spaces among nodes and leaf nodes
                while (word = words.pop()) {
                    line.push(word);
                    tspan.text(line.join(" "));
                    if (tspan.node().getComputedTextLength() > width) {
                        line.pop();
                        tspan.text(line.join(" "));
                        line = [word];
                        tspan = text.append("tspan").attr("x", x).attr("y", y).attr("dy", ++lineNumber * lineHeight + dy + "em").text(word);
                        
                    }
                }
            });
        }

        function autoscroll(position) {
            d3.select("#container")
                .transition()
               // .delay(2000)
              //  .duration(3000)
                .tween("scroll", scrollTween(document.body.getBoundingClientRect().height - window.innerHeight));
            
            function scrollTween(offset) {
                return function() {
                    var i = d3.interpolateNumber(window.pageYOffset || document.documentElement.scrollTop, offset);
                    return function(t) {scrollTo(0, i(t));};
                };
            }
        } 

    }
    
}