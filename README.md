# Bash-script-update-Solrconfig.xml
This bash script is used to automatically update (remove!-- suggestion request handler --> config) the entire solrconfig.xml on every existing collection

--> The following configuration will be deleted on solrconfig.xml:

<!-- suggestion request handler -->

	<searchComponent class="solr.SpellCheckComponent" name="suggest">
		<lst name="spellchecker">
			<str name="name">suggest</str>
			<str name="classname">org.apache.solr.spelling.suggest.Suggester</str>
			<str name="lookupImpl">org.apache.solr.spelling.suggest.tst.TSTLookupFactory</str>
			<str name="field">spell</str>
			<!-- the indexed field to derive suggestions from -->
			<float name="threshold">0.007</float>
			<str name="buildOnCommit">true</str>
		</lst>
	</searchComponent>
	<requestHandler class="org.apache.solr.handler.component.SearchHandler" name="/suggest">
		<lst name="defaults">
			<str name="spellcheck">true</str>
			<str name="spellcheck.dictionary">suggest</str>
			<str name="spellcheck.onlyMorePopular">true</str>
			<str name="spellcheck.extendedResults">false</str>
			<str name="spellcheck.count">5</str>
			<str name="spellcheck.collate">true</str>
		</lst>
		<arr name="components">
			<str>suggest</str>
		</arr>
	</requestHandler>

HOW TO USE THIS SCRIPT:
1. run the first script scriptRemoveSomeSolrConfig.sh
2. if you want to manually check the output of the first script
3. run the second script for update solrconfig.xml or rollback solrconfig.xml
