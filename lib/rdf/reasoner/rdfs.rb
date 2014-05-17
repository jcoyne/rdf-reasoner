# coding: utf-8

module RDF::Reasoner
  ##
  # Rules for generating RDFS entailment triples
  #
  # Extends `RDF::Vocabulary::Term` with specific entailment capabilities
  module RDFS
    @@rdfs_entailment_memos = {
      subClassOf: {},
      subPropertyOf: {}
    }
    ##
    # Return inferred subClassOf relationships by recursively applying to named super classes to get a complete set of classes in the ancestor chain of this class
    def _entail_subClassOf
      raise RDF::Reasoner::Error, "#{self} Can't entail subClassOf" unless class?
      @@rdfs_entailment_memos[:subClassOf][self] ||= begin
        (Array(self.subClassOf).map {|c| c._entail_subClassOf}.flatten + Array(self.subClassOf) + Array(self)).compact
      end
    end

    ##
    # Return inferred subPropertyOf relationships by recursively applying to named super classes to get a complete set of classes in the ancestor chain of this class
    def _entail_subPropertyOf
      raise RDF::Reasoner::Error, "#{self} Can't entail subPropertyOf" unless property?
      @@rdfs_entailment_memos[:subPropertyOf][self] ||= begin
        (Array(self.subPropertyOf).map {|c| c._entail_subPropertyOf}.flatten + Array(self.subPropertyOf) + Array(self)).compact
      end
    end

    ##
    # RDFS requires that if the property has a domain, and the resource has a type that some type matches every domain.
    #
    # Note that this is different than standard entailment, which simply asserts that the resource has every type in the domain, but this is more useful to check if published data is consistent with the vocabulary definition.
    #
    # @param [RDF::Resource] resource
    # @param [RDF::Queryable] queryable
    # @param [Hash{Symbol => Object}] options
    # @option options [Array<RDF::Vocabulary::Term>] :types
    #   Fully entailed types of resource, if not provided, they are queried
    def domain_acceptable_rdfs?(resource, queryable, options = {})
      raise RDF::Reasoner::Error, "#{self} can't get domains" unless property?
      if respond_to?(:domain)
        domains = Array(self.domain) - [RDF::OWL.Thing]

        # Fully entailed types of the resource
        types = options.fetch(:types) do
          queryable.query(:subject => resource, :predicate => RDF.type).
            map {|s| (t = RDF::Vocabulary.find_term(s.object)) && t.entail(:subClassOf)}.
            flatten.
            uniq.
            compact
        end unless domains.empty?

        # Every domain must match some entailed type
        Array(types).empty? || domains.all? {|d| types.include?(d)}
      else
        true
      end
    end
    
    def self.included(mod)
      mod.add_entailment :subClassOf, :_entail_subClassOf
      mod.add_entailment :subPropertyOf, :_entail_subPropertyOf
    end
  end

  # Extend the Term with this methods
  ::RDF::Vocabulary::Term.include RDFS
end