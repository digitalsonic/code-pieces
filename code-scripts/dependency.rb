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

require 'rubygems'
require 'graphviz'

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

	def get_all_children
		children = @successors.dup
		@successors.each { |successor| children |= successor.get_all_children }
		children		
	end
end

class Graph 
	def initialize
		@node_map = {}
	end

	def nodes
		@node_map.values
	end

	def add_dependency dependency
		predessors = []
		dependency.strip.split(DEPENDENCY_SPLITTOR).each do |node_names|
			node_name_array = node_names.strip.split(PARALLEL_SPLITTOR).each do |name|
				node_name = name.strip
				node = @node_map[node_name] ||= Node.new(node_name, predessors)
				predessors.each { |predessor| node.add_predessor(predessor) unless node.predessors.include? predessor }
			end
			predessors = @node_map.values.select { |node| node_name_array.include? node.name }
		end
	end
	
	def remove_redundancy_edges
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

	def roots
		init_root_nodes = []
		@node_map.values.each { |node| init_root_nodes << node if node.predessors.empty? }
		final_root_nodes = init_root_nodes.dup
		until init_root_nodes.empty?
			node1 = init_root_nodes.first
			merge_nodes = []
			final_root_nodes.each do |node2|
				merge_nodes << node2 if (node1 != node2	&& !node2.successors.include?(node1) && !(node1.get_all_children() & node2.get_all_children()).empty?)
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

				merge_nodes.each do |node| 
					init_root_nodes.delete node 
					final_root_nodes.delete node
				end
				final_root_nodes.delete node1
				final_root_nodes << vnode
			end
			init_root_nodes.delete_at 0
		end
		final_root_nodes
	end

	def has_circle
		queue = []
		traversed = []
		@node_map.values.each { |node| queue << node if node.predessors.empty? }
		until queue.empty?
			node = queue.first
			(traversed & node.successors).each do |appeared_node|
				if appeared_node.has_path_to node
					puts "WARNING!!! Circle Detected!!! Node: #{node}>#{appeared_node}"
					return true
				end
			end
			traversed << node
			node.successors.each { |succ| queue << succ unless traversed.include? succ}
			queue.delete_at 0
		end

		@node_map.values.each do |node| 
			if node.has_path_to node 
				puts "WARNING!!! Full Circle Detected!!! Node: #{node}"
				return true
			end
		end

		return false
	end
end

module GraphVizHelper
	def self.create_graph nodes
		graph = GraphViz::new("dependency")
		nodes.each do |node|
			node.successors.each { |successor| create_edge get_graph_node(node.name, graph), get_graph_node(successor.name, graph), graph }
		end
		graph
	end

	private
	def self.get_graph_node node_id, graph
		node = nil
		graph.node_attrs { |graph_node| node = graph_node if graph_node.id == node_id }
		node ||= graph.add_nodes(node_id)
	end
	
	def self.create_edge node1, node2, graph
		exist = false
		graph.each_edge { |edge| exist ||= (edge.node_one == node1.id && edge.node_two == node2.id) }
		graph.add_edges(node1, node2) unless exist
	end
end

module GraphTraverser
	def self.print_nodes roots 
		roots.each do |node| 
			output = []
			breadth_first_traverse [node], output
			output.shift if output[0] == '-'
			puts output.join(DEPENDENCY_SPLITTOR)
		end
	end

	private
	def self.breadth_first_traverse nodes, output = []
		successors = (nodes.inject([]) { |result, item| result |= item.get_all_children })
		output << (nodes.select { |node| !successors.include?(node) }).join(PARALLEL_SPLITTOR)
		new_nodes = nodes.inject([]) { |result, item| result += item.successors }
		breadth_first_traverse new_nodes, output unless new_nodes.empty?
	end
end

graph = Graph.new
IO.foreach(ARGV[0]) { |line| graph.add_dependency line }
unless graph.has_circle
	if ARGV[1]
		graph.remove_redundancy_edges
		graphviz_graph = GraphVizHelper.create_graph graph.nodes
		graphviz_graph.output(:png => ARGV[1])
	else
		roots = graph.roots
		graph.remove_redundancy_edges
		GraphTraverser.print_nodes roots
	end
end
