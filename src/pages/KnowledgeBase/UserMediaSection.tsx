import React, { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/context/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible';
import { toast } from 'sonner';
import { Loader2, Upload, Trash2, Image as ImageIcon, Video as VideoIcon, ChevronDown, ChevronUp } from 'lucide-react';

const MAX_SIZE = 50 * 1024 * 1024; // 50 MB
const BUCKET = 'knowledge-user-media';

interface MediaItem {
  id: string;
  topic_key: string;
  title: string;
  description: string | null;
  file_path: string;
  file_type: 'image' | 'video';
  mime_type: string | null;
  file_size: number | null;
  uploaded_by: string;
  created_at: string;
}

interface UserMediaSectionProps {
  topicKey: string;
  topicTitle?: string;
}

const UserMediaSection: React.FC<UserMediaSectionProps> = ({ topicKey, topicTitle }) => {
  const { user } = useAuth();
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: media, isLoading } = useQuery({
    queryKey: ['knowledge_user_media', topicKey],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('knowledge_user_media')
        .select('*')
        .eq('topic_key', topicKey)
        .order('created_at', { ascending: false });
      if (error) throw error;
      return (data || []) as MediaItem[];
    },
  });

  const { data: uploaderProfiles } = useQuery({
    queryKey: ['knowledge_user_media_profiles', media?.map((m) => m.uploaded_by).join(',')],
    queryFn: async () => {
      const ids = Array.from(new Set((media || []).map((m) => m.uploaded_by)));
      if (ids.length === 0) return {};
      const { data, error } = await supabase.from('profiles').select('id, name').in('id', ids);
      if (error) throw error;
      const map: Record<string, string> = {};
      (data || []).forEach((p: any) => (map[p.id] = p.name));
      return map;
    },
    enabled: !!media && media.length > 0,
  });

  const reset = () => {
    setTitle('');
    setDescription('');
    setFile(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleUpload = async () => {
    if (!file || !title.trim() || !user) return;
    if (file.size > MAX_SIZE) {
      toast.error('Plik jest za duży (max 50 MB)');
      return;
    }
    const isImage = file.type.startsWith('image/');
    const isVideo = file.type.startsWith('video/');
    if (!isImage && !isVideo) {
      toast.error('Dozwolone są tylko obrazy lub filmy');
      return;
    }
    setUploading(true);
    try {
      const ext = file.name.split('.').pop() || 'bin';
      const path = `${topicKey}/${user.id}/${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage.from(BUCKET).upload(path, file, {
        contentType: file.type,
        upsert: false,
      });
      if (upErr) throw upErr;
      const { error: insErr } = await supabase.from('knowledge_user_media').insert({
        topic_key: topicKey,
        title: title.trim(),
        description: description.trim() || null,
        file_path: path,
        file_type: isImage ? 'image' : 'video',
        mime_type: file.type,
        file_size: file.size,
        uploaded_by: user.id,
      });
      if (insErr) throw insErr;
      toast.success('Materiał dodany');
      reset();
      setDialogOpen(false);
      qc.invalidateQueries({ queryKey: ['knowledge_user_media', topicKey] });
    } catch (e: any) {
      console.error(e);
      toast.error(e.message || 'Nie udało się przesłać pliku');
    } finally {
      setUploading(false);
    }
  };

  const deleteMutation = useMutation({
    mutationFn: async (item: MediaItem) => {
      await supabase.storage.from(BUCKET).remove([item.file_path]);
      const { error } = await supabase.from('knowledge_user_media').delete().eq('id', item.id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success('Usunięto materiał');
      qc.invalidateQueries({ queryKey: ['knowledge_user_media', topicKey] });
    },
    onError: (e: any) => toast.error(e.message || 'Błąd usuwania'),
  });

  const getPublicUrl = (path: string) =>
    supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;

  const count = media?.length || 0;

  return (
    <div className="mt-6 border-t pt-4">
      <Collapsible open={open} onOpenChange={setOpen}>
        <div className="flex items-center justify-between gap-2">
          <CollapsibleTrigger asChild>
            <Button variant="ghost" className="gap-2">
              {open ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
              Materiały od użytkowników ({count})
            </Button>
          </CollapsibleTrigger>
          {user && (
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" variant="outline" className="gap-2">
                  <Upload className="h-4 w-4" />
                  Dodaj materiał
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Dodaj materiał {topicTitle ? `– ${topicTitle}` : ''}</DialogTitle>
                </DialogHeader>
                <div className="space-y-4">
                  <div>
                    <Label>Tytuł *</Label>
                    <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Np. Jak utworzyć dokument" />
                  </div>
                  <div>
                    <Label>Opis</Label>
                    <Textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} />
                  </div>
                  <div>
                    <Label>Plik (obraz lub film, max 50 MB) *</Label>
                    <Input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*,video/*"
                      onChange={(e) => setFile(e.target.files?.[0] || null)}
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button variant="outline" onClick={() => { reset(); setDialogOpen(false); }}>Anuluj</Button>
                  <Button onClick={handleUpload} disabled={!file || !title.trim() || uploading}>
                    {uploading ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" />Przesyłanie...</> : 'Wyślij'}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          )}
        </div>
        <CollapsibleContent>
          <div className="mt-4">
            {isLoading ? (
              <div className="flex justify-center py-6"><Loader2 className="h-6 w-6 animate-spin text-muted-foreground" /></div>
            ) : count === 0 ? (
              <p className="text-sm text-muted-foreground py-4">Brak materiałów. Bądź pierwszy i dodaj zrzut ekranu lub film instruktażowy.</p>
            ) : (
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {media!.map((item) => {
                  const url = getPublicUrl(item.file_path);
                  const canDelete = user && item.uploaded_by === user.id;
                  return (
                    <div key={item.id} className="border rounded-lg overflow-hidden bg-card">
                      <div className="aspect-video bg-muted flex items-center justify-center">
                        {item.file_type === 'image' ? (
                          <a href={url} target="_blank" rel="noopener noreferrer" className="block w-full h-full">
                            <img src={url} alt={item.title} className="w-full h-full object-cover" loading="lazy" />
                          </a>
                        ) : (
                          <video src={url} controls preload="metadata" className="w-full h-full" />
                        )}
                      </div>
                      <div className="p-3 space-y-1">
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex items-center gap-1 text-xs text-muted-foreground">
                            {item.file_type === 'image' ? <ImageIcon className="h-3 w-3" /> : <VideoIcon className="h-3 w-3" />}
                            <span>{uploaderProfiles?.[item.uploaded_by] || 'Użytkownik'}</span>
                            <span>•</span>
                            <span>{new Date(item.created_at).toLocaleDateString('pl-PL')}</span>
                          </div>
                          {canDelete && (
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-7 w-7 text-destructive"
                              onClick={() => {
                                if (confirm('Usunąć ten materiał?')) deleteMutation.mutate(item);
                              }}
                            >
                              <Trash2 className="h-3 w-3" />
                            </Button>
                          )}
                        </div>
                        <div className="font-medium text-sm leading-tight">{item.title}</div>
                        {item.description && (
                          <div className="text-xs text-muted-foreground">{item.description}</div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </CollapsibleContent>
      </Collapsible>
    </div>
  );
};

export default UserMediaSection;