require 'pathname'
require 'rest_client'
require './colors'

class Fuckhamls
  attr_reader :hamls
  attr_reader :errors

  def initialize(path)
    @path = Pathname.new(path)
    @hamls = []
    @errors = []
    puts "Buscando arquivos haml".yellow
    search_haml(@path) if @path.directory?
  end

  def convert
    if @hamls.any?
      @hamls.each_with_index do |haml, i|
        write_erb(haml, send_haml(haml))
        @hamls[i] = rename_haml(haml)
      end
    elsif File.extname(@path) == ".haml"
      send_haml(@path)
    else
      puts "Nenhum arquivo haml encontrado".red
    end
  end

  def list_haml_with_errors
    puts "\n"
    @errors.each{|error| puts "Erro ao converter: #{error.to_s}".red}
  end

  private

  def send_haml(file)
    puts "Convertendo: ".cyan + file.to_s
    erb = RestClient.post('http://haml2erb.herokuapp.com/api.html', :haml => File.read(file))
    verify_errors(erb, file)
  end

  def verify_errors(erb, file)
    if erb.lines.length > 2
      if erb.lines[1].split(" ")[0] == "unexpected"
        @errors << file
        print erb.body.red
        return File.read(file) + "\n <!-- #{erb.body} -->"
      end
      print erb.body.yellow
      return erb.body
    end
  end

  def write_erb(file, erb)
    File.open(file, "w") {|file| file.write(erb)}
    File.rename(file, rename_haml(file))
  end

  def rename_haml(file)
    unless @errors.include?(file)
      new_name = file.to_path.split(".")
      new_name[-1] = "erb"
      return new_name.join(".")
    end
    return file
  end

  def search_haml(path)
    path.children.collect do |child|
      if child.file?
        if File.extname(child) == ".haml"
          @hamls << child
          puts "HAML: ".pink + child.to_path
        end
      elsif child.directory?
        search_haml(child) + [child]
      end
    end.select { |x| x }.flatten(1)
  end
end

def copy_project(path, dest_path)
  puts "Criando copia do projeto...".yellow

  begin
    new_path = Pathname.new(FileUtils.mkdir("#{dest_path}/#{path.split('/').last}").first)
  rescue Exception => e
    puts "Já existe um projeto no diretorio de destino".red
    return
  end

  FileUtils.copy_entry(path, new_path.to_path)
  puts "Projeto copiado em #{new_path.to_path}".yellow

  return new_path
end

def fuck_it(path)
  if path
    fuck = Fuckhamls.new(path)
    fuck.convert
    fuck.list_haml_with_errors
    puts "\nConvertido #{(((fuck.hamls.length - fuck.errors.length).to_f/fuck.hamls.length.to_f)*100).round(2)}% dos arquivos"

    if ARGV.include?("sublime")
      $stdin.gets
      system("subl #{fuck.hamls.join(" ")}")
    end

  end
end

def fix_arg(arg)
  arg.chop! if arg[-1] == '/'
end

def main(path, dest_path = nil)
  if Pathname.new(path).directory?
    dest_path ? new_path = copy_project(path, dest_path) : new_path = path
    fuck_it(new_path)
  else
    puts "Nenhum projeto encontrado".red
  end
end

return if ARGV.empty?
main(ARGV[0], (ARGV[1] if ARGV[1] != "sublime"))
