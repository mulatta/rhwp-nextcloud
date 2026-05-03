<?php
/** @var array $_ */
/** @var \OCP\IL10N $l */
?>

<div id="content" class="app-rhwpviewer">
    <div id="rhwpviewer-root" data-file-id="<?php p((string)$_['fileId']); ?>">
        <h2><?php p($l->t('RHWP Viewer')); ?></h2>
        <p><?php p($l->t('Viewer route is ready.')); ?></p>
    </div>
</div>
