begin
  $evm.log("info", "Args:    #{MIQ_ARGS.inspect}")

  vm = MIQ_ARGS["vm"]
  $evm.log("info", "Inline Method: least_utilized -- vm=[#{vm.name}]")
  raise "VM not specified" if vm.nil?

  ems = vm.ext_management_system
  raise "EMS not found for VM [#{vm.name}" if vm.nil?

  host = storage = nil
  min_registered_vms = nil
  ems.hosts.each do |h|
    next unless h.power_state == "on"

    nvms = h.vms.length
    next unless min_registered_vms.nil? || nvms < min_registered_vms

    s = h.storages.max_by(&:free_space)
    next if s.nil?

    host    = h
    storage = s
    min_registered_vms = nvms
  end

  obj = $evm.object
  obj["host"]    = host    unless host.nil?
  obj["storage"] = storage unless storage.nil?
  exit MIQ_OK
rescue StandardError => err
  $evm.log("error", err.message)
  $evm.log("error", err.backtrace.join("\n"))
end
