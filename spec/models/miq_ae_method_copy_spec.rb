describe MiqAeMethodCopy do
  before do
    @src_domain     = 'SPEC_DOMAIN'
    @dest_domain    = 'FRED'
    @src_ns         = 'NS1'
    @dest_ns        = 'NS1'
    @src_class      = 'CLASS1'
    @dest_class     = 'CLASS1'
    @src_method     = 'test_method'
    @dest_method    = 'test_method_diff_script'
    @builtin_method = 'send_email'
    @dest_ns        = 'NSX/NSY'
    @src_fqname     = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{@src_method}"
    @yaml_file      = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'miq_ae_method_copy.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @src_domain)
  end

  context 'clone method' do
    before do
      @ns1 = MiqAeNamespace.lookup_by_fqname("#{@src_domain}/#{@src_ns}", false)
      @class1 = MiqAeClass.lookup_by_namespace_id_and_name(@ns1.id, @src_class)
      @meth1  = MiqAeMethod.lookup_by_class_id_and_name(@class1.id, @src_method)
    end

    it 'after copy both inline methods in DB should be congruent' do
      MiqAeMethodCopy.new(@src_fqname).to_domain(@dest_domain)
      ns2 = MiqAeNamespace.lookup_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.lookup_by_namespace_id_and_name(ns2.id, @src_class)
      meth2  = MiqAeMethod.lookup_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'after copy both builtin methods in DB should be congruent' do
      builtin_fqname = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{@builtin_method}"
      meth1 = MiqAeMethod.lookup_by_class_id_and_name(@class1.id, @builtin_method)
      MiqAeMethodCopy.new(builtin_fqname).to_domain(@dest_domain)
      ns2 = MiqAeNamespace.lookup_by_fqname("#{@dest_domain}/#{@src_ns}", false)
      class2 = MiqAeClass.lookup_by_namespace_id_and_name(ns2.id, @src_class)
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(class2.id, @builtin_method)
      validate_method(meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'overwrite an existing method' do
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
      MiqAeMethodCopy.new(@src_fqname).as(@dest_method, nil, true)
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'overwrite an existing method should raise error' do
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(@class1.id, @dest_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
      expect { MiqAeMethodCopy.new(@src_fqname).as(@dest_method) }.to raise_error(RuntimeError)
    end

    it 'copy method to a different namespace in the same domain' do
      MiqAeMethodCopy.new(@src_fqname).as(@src_method, @dest_ns, true)
      ns2 = MiqAeNamespace.lookup_by_fqname("#{@src_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.lookup_by_namespace_id_and_name(ns2.id, @src_class)
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'copy method to a different namespace in a different domain' do
      MiqAeMethodCopy.new(@src_fqname).to_domain(@dest_domain, @dest_ns, true)
      ns2 = MiqAeNamespace.lookup_by_fqname("#{@dest_domain}/#{@dest_ns}", false)
      class2 = MiqAeClass.lookup_by_namespace_id_and_name(ns2.id, @src_class)
      meth2 = MiqAeMethod.lookup_by_class_id_and_name(class2.id, @src_method)
      validate_method(@meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'copy method with embedded_methods' do
      method = MiqAeMethod.create(
        :name             => 'embedded_methods_test_method',
        :embedded_methods => [@src_fqname],
        :class_id         => MiqAeClass.first.id,
        :scope            => 'instance',
        :language         => 'ruby',
        :location         => 'inline'
      )
      src_fqname = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{method.name}"
      method_copy = MiqAeMethodCopy.new(src_fqname).to_domain(@dest_domain, @dest_ns, true)
      expect(method_copy.embedded_methods).to(eq(method.embedded_methods))
    end

    it 'copy playbook method' do
      method = MiqAeMethod.create(
        :name             => 'playbook_method',
        :embedded_methods => [],
        :class_id         => MiqAeClass.first.id,
        :scope            => 'instance',
        :language         => 'ruby',
        :location         => 'playbook',
        :options          => {
          :repository_id       => "23",
          :playbook_id         => "304",
          :credential_id       => "10",
          :vault_credential_id => "",
          :verbosity           => "1",
          :cloud_credential_id => "123",
          :execution_ttl       => "2",
          :hosts               => "201",
          :log_output          => "always",
          :become_enabled      => true
        }
      )
      src_fqname = "#{@src_domain}/#{@src_ns}/#{@src_class}/#{method.name}"
      method_copy = MiqAeMethodCopy.new(src_fqname).to_domain(@dest_domain, @dest_ns, true)
      expect(method_copy.options).to(eq(method.options))
    end
  end

  context 'copy onto itself' do
    it 'copy into the same domain' do
      expect { MiqAeMethodCopy.new(@src_fqname).to_domain(@src_domain, nil, true) }.to raise_error(RuntimeError)
    end

    it 'copy with the same name' do
      expect { MiqAeMethodCopy.new(@src_fqname).as(@src_method, nil, true) }.to raise_error(RuntimeError)
    end
  end

  context 'copy multiple' do
    it 'methods' do
      domain = 'Fred'
      fqname = 'test1'
      ids    = [1, 2, 3]
      miq_ae_method_copy = double(MiqAeMethodCopy)
      miq_ae_method = double(MiqAeMethod, :id => 1)
      expect(miq_ae_method_copy).to receive(:to_domain).with(domain, nil, false).exactly(ids.length).times.and_return(miq_ae_method)
      new_ids = [miq_ae_method.id] * ids.length
      expect(miq_ae_method).to receive(:fqname).with(no_args).exactly(ids.length).times.and_return(fqname)
      expect(MiqAeMethod).to receive(:find).with(an_instance_of(Integer)).exactly(ids.length).times.and_return(miq_ae_method)
      expect(MiqAeMethodCopy).to receive(:new).with(fqname).exactly(ids.length).times.and_return(miq_ae_method_copy)
      expect(MiqAeMethodCopy.copy_multiple(ids, domain)).to match_array(new_ids)
    end
  end

  def validate_method(meth1, meth2, status)
    obj = MiqAeMethodCompare.new(meth1, meth2)
    obj.compare
    expect(obj.status).to eq(status)
  end
end
