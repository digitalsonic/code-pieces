=begin
题目：求N以内所有素数的个数

详细说明
	具体场景包括两个
		N=10000，10万
		N=1000万，1亿
	硬件条件（ThinkPad X220）
		CPU - Intel(R) Core(TM) i5-2410M CPU @ 2.30GHz（4核）
		Memory - DDR3 1333MHz（4G）
	软件条件
		OS：ubuntu 12.04
		Ruby VM：C Ruby或者JRuby任选。如果是JRuby，选手可以指定jdk版本，也可以提供预热代码，运行模式缺省为1.9	
	要求
		代码内部需要提供一个prime函数，这个函数接受参数N，返回的结果就是N以内素数的个数。
		可以把CPU打满，节省CPU不会给你加分
		可以自由使用第三方库，但是最好不要直接使用别人写的素数库
		如果你使用JRuby，并且希望做好预热，请给出预热的代码，性能测试时会预先执行，并且不计入时间

评分说明
	功能判断，不能正确输出结果的作品直接淘汰，其余进入下一环节
	性能比较，计算时间在1秒以内不作区分，超过1秒并且性能差距超过一个数量级的结果被淘汰，其余进入下一环节
	代码行数比较，代码行数翻倍的作品淘汰，行数差距不达到翻倍效果的作品进入下一环节
	可读性比较，这块难以进行客观评价，所以我将邀请不熟悉Ruby语言的同事参与评判，投票产生最后结果

代码说明
	由于试除法代码使用了Java的并发包，务必使用JRuby运行，C Ruby无法使用！！JRuby运行命令行：
	jruby --server -Xcompile.invokedynamic=true -J-Djruby.compile.mode=FORCE -J-Djruby.thread.pooling=true -J-Xmn768m -J-Xms1280m -J-Xmx1280m -J-Xss256k -J-XX:PermSize=64m -J-XX:MaxPermSize=64m -J-XX:+UseParNewGC -J-XX:+UseConcMarkSweepGC -J-Djruby.compile.fastest=true -J-Djruby.compile.fastops=true cal_primes.rb
=end

#===========================================================
# 以下是筛选法代码
#===========================================================
def prime max_number
	nums = Array.new(max_number, 1)
	nums[0], nums[1] = 0, 0
	(4..max_number).step(2) { |n| nums[n] = 0 }
	(3..max_number).step(2) do |n|
		(n * 2...max_number).step(n) { |m| nums[m] = 0 } if (nums[n] == 1)
	end
	count = nums.count(1)
	puts "[#{count}]"
	return count
end


#===========================================================
# 以下是试除法代码
#===========================================================
require 'java'
MAX_WORKER_THREADS = 6
# 待处理任务
class Job
	attr_accessor :start_number, :end_number

	def initialize start_number, end_number
		@start_number = start_number
		@end_number = end_number
	end
end

# 计算素数，采用试除法，同时加入多线程运算
# 最大数必须是10的倍数，且大于2000
def prime2 max_number
	job_queue = java.util.concurrent.ConcurrentLinkedQueue.new
	all_primes = [2].concat(find_primes(3, 999, [2])) #初始化1000以内的素数
	tmp_primes = java.util.concurrent.ConcurrentHashMap.new

	worker_thread_block = lambda {
		job = job_queue.poll
		tmp_primes[Thread.current] = find_primes(job.start_number, job.end_number, all_primes) unless job.nil?
	}

	(1001..(max_number - 1000)).step(1000) do |start_number|
		job_queue.add(Job.new(start_number, start_number + 998))
	end
	job_queue.add(Job.new(max_number - 999, max_number - 1))

	until job_queue.empty?
		(Array.new(MAX_WORKER_THREADS) { |t| t = Thread.new &worker_thread_block}).each { |t| t.join }
		merge_primes(all_primes, tmp_primes)
	end
	puts "[#{all_primes.size}]"
	return all_primes.size
end

# 将临时计算出的结果合并到全局集合中
def merge_primes all_primes, tmp_primes
	lists = tmp_primes.values.dup
	until lists.empty?
		min, min_index = lists[0][0], 0
		lists.each_index { |i| (min, min_index = lists[i][0], i) if lists[i][0] < min }
		all_primes.concat(lists.delete_at(min_index))
	end
	tmp_primes.clear
end

# 计算指定范围内的素数
# start_number必须是奇数，且start_number<end_number！
def find_primes start_number, end_number, all_primes
	primes = []
	(start_number..end_number).step(2) do |num|
		sqrt_num = Math.sqrt(num)
		flag = check_prime num, sqrt_num, all_primes, primes
		check_prime num, sqrt_num, primes, primes if flag
	end
	return primes
end

# 检查指定的数字是否是素数
def check_prime num, sqrt_num, all_primes, primes
	need_post_process = true
	all_primes.each do |prime| 
		if (num % prime == 0.0)
			need_post_process = false
			break
		end
		if (prime > sqrt_num)
			primes << num.to_f
			need_post_process = false
			break
		end
	end	
	return need_post_process
end


#===========================================================
# 以下是性能测试代码
#===========================================================

# 预热
prime(10000)

# 评测
require 'benchmark'

Benchmark.bm do |x|
   (4..8).each do |i|
      x.report(10**i){ prime(10**i) }
   end
end