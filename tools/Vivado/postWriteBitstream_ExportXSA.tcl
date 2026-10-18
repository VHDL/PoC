set ProjectName [get_property NAME [current_project]]

regexp {^project_(.*)_routed$} $ProjectName -> ProjectName

set xsaFilePath "../../../${ProjectName}.xsa"

puts "Writing XSA file to '${xsaFilePath}'"
write_hw_platform -fixed -include_bit -force -file $xsaFilePath
