require 'rubygems'
require 'libxml'
require 'iconv'
require 'models/catalog'
require 'models/category'
require 'models/category_statistic'
require 'models/study'
require 'models/study_date'
require 'models/ddi_variable'
require 'models/summary_stat'
require 'logger'
module DDI
  class Parser
    
    attr_accessor :logger
        
    def initialize
      @logger = Logger.new('ddi-parser.log')
    end
    
    #Given a DDI metadata file, parse it and return study information
    #
    #Returns a Nesstar::Study object
    def parse ddi_file
      @logger.info 'Parsing DDI file ' + ddi_file
      catalog = DDI::Catalog.new
      study = DDI::Study.new
      study_info_hash = Hash.new
#TODO This will not work on windows since it depends on the unix tool file need to use a different way. Possibly use rchardet instead
      begin
        encode_type = `file --mime -br #{ddi_file}`.gsub(/\n/,"").split(';')[1].split('=')[1]
      rescue
        
      end
      #have to convert to UTF-8 for libxml
      contents = File.open(ddi_file).read
      output = Iconv.conv("UTF-8", encode_type, contents)
      converted_file = File.join(File.dirname(ddi_file), "converted_file.xml")
      file = File.open(converted_file, 'w')
      file.write(output)
      file.close
      parser = LibXML::XML::Parser.file(converted_file)
      doc = parser.parse
      studynodes = doc.find('//stdyDscr')
      abstracts = studynodes[0].find('//abstract')
      abstract = ""
      abstracts.each {|ab| abstract << ab.content.strip}
      abstract.strip!
      study.abstract = abstract
      study.title = studynodes[0].find('//stdyDscr/citation/titlStmt/titl')[0].first.content.strip unless studynodes[0].find('//stdyDscr/citation/titlStmt/titl')[0] == nil
      study.id = studynodes[0].find('//IDNo')[0].first.content.strip unless studynodes[0].find('//IDNo')[0] == nil
      
      #start and finish dates for study
      dates = []
      date = studynodes[0].find('//sumDscr/collDate')
      date.each do |d|
        a = d.attributes
        unless a.length == 0
          study_date = DDI::StudyDate.new
          study_date.type = a.get_attribute('event').value.strip
          study_date.date = a.get_attribute('date').value.strip
          dates.push(study_date)
        end
      end
      study.dates = dates
      studynodes[0].find('//sampProc')[0] ? samp_node = studynodes[0].find('//sampProc')[0] : samp_node = nil
      unless samp_node == nil
        study.sampling_procedure = samp_node.first.content.strip unless samp_node.first == nil
      end
      # study.weight = studynodes[0].find('//sampProc')[0].first.content
      study.ddi_variables = get_variable_information doc
      return study
    end
    
    private
    
    #information about the variables
    def get_variable_information doc
      variables = []
      variable_info_hash = Hash.new
      docnodes = doc.find('//dataDscr')
      vargroups = docnodes[0].find('//dataDscr/varGrp')
      vargroups.each do |vargroup|
        #hash which holds all the variable groups
        a = vargroup.attributes
        groups = a.get_attribute('var')
        if groups != nil
          groups = a.get_attribute('var')
          variable_info_hash[vargroup.find('./labl')[0].first.content] = groups.value.split(' ') unless vargroup.find('./labl')[0] == nil
        # else
        #             variable_info_hash[vargroup.find('./labl')[0].first.content] = groups.value.split(' ')
        end
      end
      vars = docnodes[0].find('//dataDscr/var')
      vars.each do |var|
        variable = DDI::DDIVariable.new
        var_attr = var.attributes
        variable.id = var_attr.get_attribute('ID').value.strip unless var_attr.get_attribute('ID') == nil
        variable.name = var_attr.get_attribute('name').value.strip unless var_attr.get_attribute('name') == nil
        variable.file = var_attr.get_attribute('files').value.strip unless var_attr.get_attribute('files') == nil
        variable.interval = var_attr.get_attribute('intrvl').value.strip unless var_attr.get_attribute('intrvl') == nil
        variable.label = var.find('./labl')[0].content.strip unless var.find('./labl')[0] == nil 
        #these things never seem consistent with the schema, might be an inner element, might be an attribute!
        if var.find('./labl')[0] == nil
          variable.label = var_attr.get_attribute('labl').value.strip unless var_attr.get_attribute('labl') == nil
        end
        rng = var.find('./valrng')
        if rng != nil
          if rng[0] != nil
            unless rng[0].first == nil
              range_attr = rng[0].first.attributes
              max_val = range_attr.get_attribute('max')
              variable.max = max_val.value.strip unless max_val == nil
              min_val = range_attr.get_attribute('min')
              variable.min = min_val.value.strip unless min_val == nil
            end
          end
        end
        q = var.find('./qstn')
        if q[0] != nil
          ql = q[0].find('./qstnLit')
          if ql != nil
            if ql[0] != nil
              variable.question = ql[0].first.content.strip
            end
          end
          iv = q[0].find('./ivuInstr')
          if iv != nil
            if iv[0] != nil
              variable.interview_instruction = iv[0].first.content.strip
            end
          end
        end
        stats = var.find('./sumStat')
        summary_stats = []
        stats.each do |stat|
          a = stat.attributes
          # summary_stats[a.get_attribute('type').value] = stat.first.content
          statistic = DDI::SummaryStat.new
          statistic.type = a.get_attribute('type').value.strip
          statistic.value = stat.first.content.strip
          summary_stats.push(statistic)
        end
        variable.summary_stats = summary_stats
        catgry = var.find('./catgry')
        categories = []
        #categories in ddi are value domains in mb
        catgry.each do |cat|
          category = DDI::Category.new
          valxml = cat.find('./catValu')
          if valxml != nil && valxml[0] != nil
            category.value = valxml[0].first.content.strip unless valxml[0].first == nil
          else
            category.value = 'N/A'
          end
          labxml = cat.find('./labl')
          if labxml != nil && labxml[0] != nil
            category.label = labxml[0].first.content.strip unless labxml[0].first == nil
          else
            category.label = 'N/A'
          end
          catstats = cat.find('./catStat')
          category_statistics = []
          catstats.each do |catstat|
            category_statistic = DDI::CategoryStatistic.new
            a = catstat.attributes
            if a != nil && a.get_attribute('type') != nil
              category_statistic.type = a.get_attribute('type').value.strip
              category_statistic.value = catstat.first.content.strip unless catstat.first == nil
              category_statistics.push(category_statistic)
            end
          end
          category.category_statistics = category_statistics
          categories.push(category)
        end
        #what group is the variable in
        variable_info_hash.each_key do |key|
          if variable_info_hash[key].include?(variable.id)
            variable.group = key.strip
            break
          end
        end
        
        variable.categories = categories
        variables.push(variable)
      end
      return variables
    end
    
  end
end
