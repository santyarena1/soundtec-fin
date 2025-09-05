import { Router } from 'express';
import { listPriceListsController, importPriceListController } from './pricelists.controller';
import { importXlsxController } from './import-xlsx.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';
import { upload } from '../../middleware/upload';

const router = Router();

// SÃ³lo admin por ahora
router.use(authGuard, adminGuard);

router.get('/', listPriceListsController);
router.post('/import', importPriceListController);

// Nuevo: importaciÃ³n por XLSX (multipart/form-data con key 'file')
router.post('/import-xlsx', upload.single('file'), importXlsxController);

export default router;
