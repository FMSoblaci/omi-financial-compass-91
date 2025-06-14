import React from 'react';
import { 
  Table, 
  TableHeader, 
  TableBody, 
  TableRow, 
  TableHead, 
  TableCell 
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { KpirTransaction } from '@/types/kpir';
import { Spinner } from '@/components/ui/Spinner';
import { Pencil, Split } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';

interface KpirTableProps {
  transactions: KpirTransaction[];
  loading: boolean;
  onShowDocument?: (doc: KpirTransaction["document"]) => void;
}

const KpirTable: React.FC<KpirTableProps> = ({ transactions, loading, onShowDocument }) => {
  const { user } = useAuth();
  const isAdmin = user?.role === 'prowincjal' || user?.role === 'admin';

  // Filtrujemy tylko operacje główne - ukrywamy sklonowane operacje (subtransakcje)
  // oraz operacje bez opisów
  const mainTransactions = React.useMemo(() => {
    return transactions.filter(transaction => 
      !transaction.parent_transaction_id && 
      transaction.description && 
      transaction.description.trim() !== ''
    );
  }, [transactions]);

  if (loading) {
    return (
      <div className="flex justify-center items-center py-10">
        <Spinner size="lg" />
      </div>
    );
  }

  if (!mainTransactions.length) {
    return (
      <div className="text-center py-10 text-omi-gray-500">
        Brak operacji do wyświetlenia
      </div>
    );
  }

  const renderTransactionRow = (transaction: KpirTransaction) => {
    // Sprawdź czy ta transakcja ma subtransakcje (jest split-parentem)
    const hasSubTransactions = transactions.some(t => t.parent_transaction_id === transaction.id);

    return (
      <TableRow key={transaction.id} className="hover:bg-omi-100">
        <TableCell>{transaction.formattedDate}</TableCell>
        <TableCell>{transaction.document_number || '-'}</TableCell>
        <TableCell>
          <div className="flex items-center">
            {hasSubTransactions && (
              <Split className="h-4 w-4 text-orange-500 mr-2" />
            )}
            {transaction.description}
          </div>
        </TableCell>
        <TableCell>
          {transaction.currency}
          {transaction.currency !== 'PLN' && transaction.exchange_rate && (
            <span className="text-xs text-omi-gray-500 block">
              kurs: {transaction.exchange_rate.toFixed(4)}
            </span>
          )}
        </TableCell>
        <TableCell>
          {transaction.document ? (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => onShowDocument?.(transaction.document)}
              title="Edytuj dokument"
            >
              <span className="sr-only">Edytuj dokument</span>
              <svg className="h-5 w-5 text-blue-700" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <circle cx="11" cy="11" r="8"/>
                <line x1="21" y1="21" x2="16.65" y2="16.65"/>
              </svg>
            </Button>
          ) : (
            <span className="text-xs text-gray-400 italic">Brak</span>
          )}
        </TableCell>
      </TableRow>
    );
  };

  return (
    <div className="overflow-x-auto">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Data</TableHead>
            <TableHead>Nr dokumentu</TableHead>
            <TableHead>Opis</TableHead>
            <TableHead>Waluta</TableHead>
            <TableHead>Dokument</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {mainTransactions.map(transaction => renderTransactionRow(transaction))}
        </TableBody>
      </Table>
    </div>
  );
};

export default KpirTable;
