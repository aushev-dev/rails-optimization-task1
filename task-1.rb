require 'json'
require 'ruby-progressbar'

class User
  attr_reader :attributes, :sessions

  def initialize(attributes:, sessions:)
    @attributes = attributes
    @sessions = sessions
  end
end

def parse_user(user)
  fields = user.split(',')
  parsed_result = {
    'id' => fields[1],
    'first_name' => fields[2],
    'last_name' => fields[3],
    'age' => fields[4],
  }
end

Session = Struct.new(:user_id, :session_id, :browser, :time, :date)

def parse_session(session)
  _, user_id, session_id, browser, time, date = session.split(',', 6)
  Session.new(user_id, session_id, browser, time, date)
end

def collect_stats_from_users(report, users_objects, &block)
  users_objects.each do |user|
    user_key = "#{user.attributes['first_name']}" + ' ' + "#{user.attributes['last_name']}"
    report['usersStats'][user_key] ||= {}
    report['usersStats'][user_key] = report['usersStats'][user_key].merge(block.call(user))
  end
end

def work(file_name: "data.txt", disable_gc: false, progress_bar: true)
  GC.disable if disable_gc
  file_lines = File.read(file_name).split("\n")

  users = []
  sessions = []

  file_progressbar = progress_bar ? ProgressBar.create(title: "Reading File", total: file_lines.count, format: '%t: |%B| %p%% %e') : nil

  file_lines.each do |line|
    case
    when line.start_with?('user,')
      users << parse_user(line)
    when line.start_with?('session,')
      sessions << parse_session(line)
    end
    increment_progressbar(file_progressbar)
  end

  # Отчёт в json
  #   - Сколько всего юзеров +
  #   - Сколько всего уникальных браузеров +
  #   - Сколько всего сессий +
  #   - Перечислить уникальные браузеры в алфавитном порядке через запятую и капсом +
  #
  #   - По каждому пользователю
  #     - сколько всего сессий +
  #     - сколько всего времени +
  #     - самая длинная сессия +
  #     - браузеры через запятую +
  #     - Хоть раз использовал IE? +
  #     - Всегда использовал только Хром? +
  #     - даты сессий в порядке убывания через запятую +

  report = {}

  report[:totalUsers] = users.count

  # Подсчёт количества уникальных браузеров
  unique_browsers = sessions.map { |session| session['browser'] }.uniq

  report['uniqueBrowsersCount'] = unique_browsers.count

  report['totalSessions'] = sessions.count

  report['allBrowsers'] =
    sessions
      .map { |s| s['browser'] }
      .map { |b| b.upcase }
      .sort
      .uniq
      .join(',')

  # Статистика по пользователям
  sessions_by_user = {}
  sessions.each do |session|
    user_id = session['user_id']
    sessions_by_user[user_id] ||= []
    sessions_by_user[user_id] << session
  end

  user_progressbar = progress_bar ? ProgressBar.create(title: "Processing Users", total: users.count, format: '%t: |%B| %p%% %e') : nil

  users_objects = users.map do |user|
    user_id = user['id']
    user_sessions = sessions_by_user[user_id] || []
    user_object = User.new(attributes: user, sessions: user_sessions)
    increment_progressbar(user_progressbar)
    user_object
  end

  report['usersStats'] = {}

  # Собираем количество сессий по пользователям
  collect_stats_from_users(report, users_objects) do |user|
    { 'sessionsCount' => user.sessions.count }
  end

  # Собираем количество времени по пользователям
  collect_stats_from_users(report, users_objects) do |user|
    { 'totalTime' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.sum.to_s + ' min.' }
  end

  # Выбираем самую длинную сессию пользователя
  collect_stats_from_users(report, users_objects) do |user|
    { 'longestSession' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.max.to_s + ' min.' }
  end

  # Браузеры пользователя через запятую
  collect_stats_from_users(report, users_objects) do |user|
    { 'browsers' => user.sessions.map {|s| s['browser']}.map {|b| b.upcase}.sort.join(', ') }
  end

  # Хоть раз использовал IE?
  collect_stats_from_users(report, users_objects) do |user|
    { 'usedIE' => user.sessions.map{|s| s['browser']}.any? { |b| b.upcase =~ /INTERNET EXPLORER/ } }
  end

  # Всегда использовал только Chrome?
  collect_stats_from_users(report, users_objects) do |user|
    { 'alwaysUsedChrome' => user.sessions.map{|s| s['browser']}.all? { |b| b.upcase =~ /CHROME/ } }
  end

  # Даты сессий через запятую в обратном порядке в формате iso8601
  collect_stats_from_users(report, users_objects) do |user|
    { 'dates' => user.sessions.map{|s| s['date']}.sort.reverse }
  end

  File.write('result.json', "#{report.to_json}\n")
end

def increment_progressbar(progressbar)
  progressbar&.increment
end
