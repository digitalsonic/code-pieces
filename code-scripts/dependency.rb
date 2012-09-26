require 'rubygems'
require 'graphviz'

#=INSTALL
# 1. Install Ruby interpreter and Graphviz
# 2. gem install ruby-graphviz
#
#=EXCUTION
# ruby dependency.rb <input_file> [output.png]
#
#=EXAMPLE INPUT
# a>b,c>d
# b>e

DEPENDENCY_SPLITTOR = '>'
PARALLEL_SPLITTOR = ','

class Node
	attr_accessor :predessors, :successors
	attr_reader :name

	def initialize name, predessors = []
		@name = name
		@predessors = []
		@successors = []
		predessors.each { |node| add_predessor node }
	end

	def to_s
		@name
	end

	def has_path_to node 
		result = @successors.include? node 
		@successors.each do |successor| 
			result ||= successor.has_path_to node 
			break if result
		end
		result
	end

	def add_predessor predessor
		predessor.successors << self
		@predessors << predessor
	end

	def remove_successor successor
		successor.predessors.delete self
		@successors.delete successor
	end
end

def get_all_children node
	children = node.successors.dup
	node.successors.each { |successor| children |= get_all_children(successor) }
	children
end

def build_graph dependency, node_map
	predessors = []
	dependency.strip.split(DEPENDENCY_SPLITTOR).each do |node_names|
		node_name_array = node_names.strip.split(PARALLEL_SPLITTOR).each do |node_name|
			node = node_map[node_name] ||= Node.new(node_name, predessors)
			predessors.each { |predessor| node.add_predessor(predessor) unless node.predessors.include? predessor }
		end
		predessors = node_map.values.select { |node| node_name_array.include? node.name }
	end
end

def remove_redundancy_edges nodes
	nodes.each do |node|
		node.successors.dup.each do |successor|
			node.successors.select { |element| element != successor }.each do |element|
				node.remove_successor(successor) if element.has_path_to successor
			end
		end
	end

	nodes.each do |node|
		node.successors.dup.each do |successor|
			node.predessors.each do |predessor|
				predessor.successors.select { |element| element != node }.each do |element|
					node.remove_successor(successor) if element.has_path_to successor
				end 
			end
		end
	end
end

def get_graph_node node_id, graph
	node = nil
	graph.node_attrs { |graph_node| node = graph_node if graph_node.id == node_id }
	node ||= graph.add_nodes(node_id)
end

def create_edge node1, node2, graph
	exist = false
	graph.each_edge { |edge| exist ||= (edge.node_one == node1.id && edge.node_two == node2.id) }
	graph.add_edges(node1, node2) unless exist
end

def create_graph nodes
	graph = GraphViz::new("dependency")
	nodes.each do |node|
		node.successors.each { |successor| create_edge get_graph_node(node.name, graph), get_graph_node(successor.name, graph), graph }
	end
	graph
end

def get_root_nodes node_map
	init_root_nodes = []
	node_map.values.each { |node| init_root_nodes << node if node.predessors.empty? }
	final_root_nodes = init_root_nodes.dup
	init_root_nodes.each do |node1|
		merge_nodes = []
		final_root_nodes.each do |node2|
			merge_nodes << node2 if (node1 != node2	&& !node2.successors.include?(node1) && !(get_all_children(node1) & get_all_children(node2)).empty?)
		end
		unless merge_nodes.empty?
			vnode = Node.new '-'
			node1.add_predessor vnode

			merge_nodes.each do |node| 
				if node.name == '-'
					node.successors.each { |s| s.add_predessor vnode}
					vnode.successors.each { |s| node.remove_successor s }
				else
					node.add_predessor vnode
				end
			end
	
			final_root_nodes.delete node1
			final_root_nodes.delete_if { |node| merge_nodes.include? node }
			final_root_nodes << vnode
		end
	end
	final_root_nodes
end

def print_nodes roots 
	roots.each do |node| 
		output = []
		breadth_first_traverse [node], output
		output.shift if output[0] == '-'
		puts output.join(DEPENDENCY_SPLITTOR)
	end
end

def breadth_first_traverse nodes, output = []
	successors = (nodes.inject([]) { |result, item| result |= get_all_children(item) })
	output << (nodes.select { |node| !successors.include?(node) }).join(PARALLEL_SPLITTOR)
	new_nodes = nodes.inject([]) { |result, item| result += item.successors }
	breadth_first_traverse new_nodes, output unless new_nodes.empty?
end

node_map = {}
IO.foreach(ARGV[0]) { |line| build_graph line, node_map }
if ARGV[1]
	remove_redundancy_edges node_map.values
	graph = create_graph node_map.values
	graph.output(:png => ARGV[1])
else
	roots = get_root_nodes(node_map)
	remove_redundancy_edges node_map.values
	print_nodes roots
end