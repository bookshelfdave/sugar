require 'rubygems'
require 'bundler/setup'
require 'parslet'
require 'octokit'

tables = %w{issues pull_requests prs users}

issue_fields = [:id, :number, :title, :user, :labels,
                :state, :assignee, :milestone, :comments,
                :created_at, :updated_at, :closed_at, :pull_request, :body ]

class GHQL < Parslet::Parser
    rule(:select)       { str('select') >> space? }
    rule(:from)         { str('from') >> space? }
    rule(:all)          { str('*').as(:all) >> space? }
    rule(:space)        { match('\s').repeat(1) }
    rule(:space?)       { space.maybe }
    rule(:comma)        { space? >> str(',') >> space? }
    rule(:id)           { match('[a-z_]').repeat(1).as(:id) >> space? }
    rule(:slash)        { str('/') >> space? }

    rule(:wherestring)          { str('"') >>
                            (
                               str('\\') >> any |
                               str('"').absent? >> any
                            ).repeat.as(:wherestring) >>
                          str('"')
                        }

    rule(:columns)      { (id >> (comma >> id).repeat).maybe.as(:columns) }
    rule(:path)         { (id.as(:org) >> slash >> id.as(:repo) >> slash >> id.as(:ghtype)).as(:path) }
    rule(:whereclause)  { (str('where') >> space >> wherestring).maybe.as(:whereclause) }
    rule(:select_expression) { (select >>
                                  (all | columns) >>
                                from >>
                                  path >>
                                whereclause
                                 ).as(:select_expression) }

    rule(:expression) { select_expression.as(:expression) }
    root(:expression)
end

class GHQLTransform < Parslet::Transform
  #rule(:select_expression => subtree(:expr)) { puts ">>>" }
  #rule(:locator => simple(:x)) { puts(x) }
  #rule(:expression => subtree(:expr)) { puts "Expression" }
  #rule(:select_expression => subtree(:sel_expr)) { puts "Sel Expr" }
  rule(:id => simple(:s)) { String.new(s) }
  rule(:wherestring => simple(:s)) { String.new(s) }
  rule(:columns=> subtree(:cols), :path=> subtree(:p), :whereclause=>subtree(:w)) {
    org = p[:org]
    repo = p[:repo]
    ghtype = p[:ghtype]
    if ghtype == "issues"
      issues = Octokit.issues("#{org}/#{repo}")
      results = issues.select do |i|
          result = eval("i.#{w}")
      end
      mappedresults = results.map do |r|
        r = cols.map do |c|
          eval("r.#{c}")
        end
      end

      puts mappedresults.join(",")
    end
  }
end

t = 'select number, id, title from basho/eleveldb/issues where "number==71"'
puts t
tree = GHQL.new.parse(t)
GHQLTransform.new.apply(tree)
puts "\n"
t = 'select number, title, created_at from basho/eleveldb/issues where "title==\'Specify the Snappy libdir install location\'"'
puts t
tree = GHQL.new.parse(t)
GHQLTransform.new.apply(tree)

