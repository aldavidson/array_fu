
class Array
  # Construct a hash of objects, keyed by some object attribute.
  def hash_by(attribute)
    results = self.inject({}) do |results, obj|
      val = (attribute.is_a? Symbol) ? obj.send(attribute) : obj.send(:eval, attribute)
      results[val] = [] unless results[val]
      results[val] << obj
      results
    end
    
    results.to_hash
  end
  
  # use this to normalize an array of objects
  # by one of their properties
  def normalize(params)
    clone.normalize!(params)
  end
  
  def normalize!(params)
    max_val = self.map{ |v| v.send(params[:property]).to_f }.max
    return self unless max_val && max_val > 0
    map!{|it| it.update_attribute( params[:property], (it.send(params[:property]).to_f * params[:normalize_to]/max_val).round); it }
  end
  
  def index_where(&block)
    self.each_with_index{ |i, index|
        return index if block.call(i)
    }
    nil
  end
  
  def uniq_ignoring_case
    # simple uniq first, to trim down the search space for case-insensitive uniq
    result = self.uniq
    de_duped = []
    thrash = []
    result.each do |element|
      unless thrash.include?(element.downcase)
        de_duped << element
        thrash << element.downcase
      end
    end
    de_duped
  end
end

class Hash
  # delete many keys at once
  def delete_many( *args )
    keys = *args.to_a
    keys.to_a.each do |k|
      self.delete( k )
    end
    self
  end
  
  # lets you do :
  #   {:simian=>'chimp', :fish=>'trout', :rodent=>'vole'} - [:simian, :fish]
  # => {:rodent=>'vole'}
  def -( *args )
    keys = *args.to_a
    hash = self.clone
    keys.each{ |k| hash.delete(k) }
    hash
  end
  
  def normalize_to!( limit )
    total = values.inject(0){ | sum, thing| sum += thing.to_i }
    clone.each{ |key, val| 
      scaled_count = (limit * val.to_i / total).to_i
      self[key] = (scaled_count < 1 ? 1 : scaled_count)
    } if total > limit
    self
  end
  
  # returns a new hash with just the key/value pairs from this hash given in keys
  # e.g. 
  #  { :simian=>'chimp', :fox=>'urban', :rodent=>'vole'}.intersection( [:rodent, :fox] ) 
  #  => {:fox=>'urban', :rodent=>'vole'}
  def intersection( keys )
    h = {}
    keys.each{ |k| h[k] = self[k] }
    h
  end
  
  def recursive_symbolize_keys!
    symbolize_keys!
    values.select { |v| v.is_a?(Hash) }.each { |h| h.recursive_symbolize_keys! }
    self
  end
end


# from http://redcorundum.blogspot.com/2007/02/have-you-seen-that-key.html
module Enumerable
  def uniq_by
    seen = Hash.new { |h,k| h[k] = true; false }
    reject { |v| seen[yield(v)] }
  end
end

# add a count_by method onto active record model classes
module ActiveRecord
  class Base
    def self.count_by_field( field, conditions = nil )    
      counts = find_by_sql( "SELECT #{field}, count(*) AS count FROM #{self.table_name} #{conditions ? "WHERE #{conditions}" : ''} GROUP BY #{field} ORDER BY #{field}")
      result = {}
      counts.each{ |c| result[c[field]] = c.count }
      result
    end
    def self.count_by_group( args )    
      args = {:fields=>args.to_a} unless args.is_a?(Hash)
      col_names = args[:fields].map{ |f| f.is_a?(Hash) ? f.keys.first.to_s : f.to_s }.join( ', ' ) 
      col_defs = args[:fields].map{ |f| f.is_a?(Hash) ? "(#{f.values.first}) AS #{f.keys.first.to_s}" : f.to_s }.join(', ')
      where_clause = args[:conditions] ? "WHERE #{args[:conditions]}" : ""
     
      counts = find_by_sql( "SELECT #{col_defs}, count(*) AS count FROM #{self.table_name} #{where_clause} GROUP BY #{col_names} ORDER BY #{col_names}")
      counts
    end
  end
end
